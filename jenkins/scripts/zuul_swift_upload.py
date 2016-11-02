#!/usr/bin/python
#
# Copyright 2014 Rackspace Australia
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

"""
Utility to upload folders to swift using the form post middleware
credentials provided by zuul
"""

import argparse
import logging
import glob2
import hashlib
import json
import magic
import mimetypes
import os
import Queue
import requests
import requests.exceptions
import requestsexceptions
import stat
import sys
import tempfile
import threading
import time

# Map mime types to apache icons
APACHE_MIME_ICON_MAP = {
    '_default': '/icons/unknown.png',
    'application/gzip': '/icons/compressed.png',
    'folder': '/icons/folder.png',
    'text/html': '/icons/text.png',
    'text/plain': '/icons/text.png',
    '../': '/icons/back.png',
}

# file_detail format: A dictionary containing details of the file such as
#                     full url links or relative path names etc.
#                     Used to generate indexes with links or as the file path
#                     to push to swift.
#        file_details = {
#            'filename': The base filename to appear in indexes,
#            'path': The path on the filesystem to the source file
#                    (absolute or relative),
#            'relative_name': The file relative name. Used as the object name
#                             in swift, is typically the rel path to the file
#                             list supplied,
#            'url': The URL to the log on the log server (absolute, supplied
#                   by logserver_prefix and swift_destination_prefix),
#            'metadata': {
#                'mime': The filetype/mime,
#                'last_modified': Modification timestamp,
#                'size': The filesize in bytes,
#            }
#        }


def get_mime_icon(mime, filename=''):
    if filename == '../' and filename in APACHE_MIME_ICON_MAP:
        return APACHE_MIME_ICON_MAP[filename]
    if mime in APACHE_MIME_ICON_MAP:
        return APACHE_MIME_ICON_MAP[mime]
    return APACHE_MIME_ICON_MAP['_default']


def generate_log_index(folder_links, header_message='',
                       append_footer='index_footer.html'):
    """Create an index of logfiles and links to them"""

    output = '<html><head><title>Index of results</title></head><body>\n'
    output += '<h1>%s</h1>\n' % header_message
    output += '<table><tr><th></th><th>Name</th><th>Last Modified</th>'
    output += '<th>Size</th>'

    file_details_to_append = None
    for file_details in folder_links:
        output += '<tr>'
        output += (
            '<td><img alt="[ ]" title="%(m)s" src="%(i)s"></img></td>' % ({
            'm': file_details['metadata']['mime'],
            'i': get_mime_icon(file_details['metadata']['mime'],
                               file_details['filename']),
            }))
        output += '<td><a href="%s">%s</a></td>' % (file_details['url'],
                                                    file_details['filename'])
        output += '<td>%s</td>' % time.asctime(
            file_details['metadata']['last_modified'])
        if file_details['metadata']['mime'] == 'folder':
            size = str(file_details['metadata']['size'])
        else:
            size = sizeof_fmt(file_details['metadata']['size'], suffix='')
        output += '<td style="text-align: right">%s</td>' % size
        output += '</tr>\n'

        if append_footer and append_footer in file_details['filename']:
            file_details_to_append = file_details

    output += '</table>'

    if file_details_to_append:
        output += '<br /><hr />'
        try:
            with open(file_details_to_append['path'], 'r') as f:
                output += f.read()
        except IOError:
            logging.exception("Error opening file for appending")

    output += '</body></html>\n'
    return output


def make_index_file(folder_links, header_message='',
                    index_filename='index.html',
                    append_footer='index_footer.html'):
    """Writes an index into a file for pushing"""
    for file_details in folder_links:
        # Do not generate an index file if one exists already.
        # This may be the case when uploading other machine generated
        # content like python coverage info.
        if index_filename == file_details['filename']:
            return
    index_content = generate_log_index(folder_links, header_message,
                                       append_footer)
    tempdir = tempfile.mkdtemp()
    fd = open(os.path.join(tempdir, index_filename), 'w')
    fd.write(index_content)
    return os.path.join(tempdir, index_filename)


def sizeof_fmt(num, suffix='B'):
    # From http://stackoverflow.com/questions/1094841/
    # reusable-library-to-get-human-readable-version-of-file-size
    for unit in ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Y', suffix)


def get_file_mime(file_path):
    """Get the file mime using libmagic"""

    if not os.path.isfile(file_path):
        return None

    if hasattr(magic, 'from_file'):
        mime = magic.from_file(file_path, mime=True)
    else:
        # no magic.from_file, we might be using the libmagic bindings
        m = magic.open(magic.MAGIC_MIME)
        m.load()
        mime = m.file(file_path).split(';')[0]
    # libmagic can fail to detect the right mime type when content
    # is too generic. The case for css or js files. So in case
    # text/plain is detected then we rely on the mimetype db
    # to guess by file extension.
    if mime == 'text/plain':
       mime_guess = mimetypes.guess_type(file_path)[0]
       mime = mime_guess if mime_guess else mime
    return mime


def get_file_metadata(file_path):
    metadata = {}
    st = os.stat(file_path)
    metadata['mime'] = get_file_mime(file_path)
    metadata['last_modified'] = time.gmtime(st[stat.ST_MTIME])
    metadata['size'] = st[stat.ST_SIZE]
    return metadata


def get_folder_metadata(file_path, number_files=0):
    metadata = {}
    st = os.stat(file_path)
    metadata['mime'] = 'folder'
    metadata['last_modified'] = time.gmtime(st[stat.ST_MTIME])
    metadata['size'] = number_files
    return metadata


def swift_form_post_queue(file_list, url, hmac_body, signature,
                          delete_after=None, additional_headers=None):
    """Queue up files for processing via requests to FormPost middleware"""

    # We are uploading the file_list as an HTTP POST multipart encoded.
    # First grab out the information we need to send back from the hmac_body
    payload = {}

    (object_prefix,
     payload['redirect'],
     payload['max_file_size'],
     payload['max_file_count'],
     payload['expires']) = hmac_body.split('\n')
    payload['signature'] = signature
    try:
        payload['max_file_size'] = int(payload['max_file_size'])
        payload['max_file_count'] = int(payload['max_file_count'])
        payload['expires'] = int(payload['expires'])
    except ValueError:
        raise Exception("HMAC Body contains unexpected (non-integer) data.")

    headers = {}
    if delete_after:
        payload['x_delete_after'] = delete_after
    if additional_headers:
        headers.update(additional_headers)

    queue = Queue.Queue()
    # Zuul's log path is sometimes generated without a tailing slash. As
    # such the object prefix does not contain a slash and the files would
    # be  uploaded as 'prefix' + 'filename'. Assume we want the destination
    # url to look like a folder and make sure there's a slash between.
    filename_prefix = '/' if url[-1] != '/' else ''
    for i, f in enumerate(file_list):
        if os.path.getsize(f['path']) > payload['max_file_size']:
            sys.stderr.write('Warning: %s exceeds %d bytes. Skipping...\n'
                             % (f['path'], payload['max_file_size']))
            continue
        fileinfo = {'file01': (filename_prefix + f['relative_name'],
                               f['path'],
                               get_file_mime(f['path']))}
        filejob = (url, payload, fileinfo, headers)
        queue.put(filejob)
    return queue


def build_file_list(file_path, logserver_prefix, swift_destination_prefix,
                    create_dir_indexes=True, create_parent_links=True,
                    root_file_count=0, append_footer='index_footer.html'):
    """Generate a list of files to upload to zuul. Recurses through directories
       and generates index.html files if requested."""

    # file_list: A list of files to push to swift (in file_detail format)
    file_list = []

    destination_prefix = os.path.join(logserver_prefix,
                                      swift_destination_prefix)

    if os.path.isfile(file_path):
        filename = os.path.basename(file_path)
        full_path = file_path
        relative_name = filename
        url = os.path.join(destination_prefix, filename)

        file_details = {
            'filename': filename,
            'path': full_path,
            'relative_name': relative_name,
            'url': url,
            'metadata': get_file_metadata(full_path),
        }

        file_list.append(file_details)

    elif os.path.isdir(file_path):
        if file_path[-1] == os.sep:
            file_path = file_path[:-1]
        parent_dir = os.path.dirname(file_path)
        for path, folders, files in os.walk(file_path):
            # relative_path: The path between the given director and the one
            #                being currently walked.
            relative_path = os.path.relpath(path, parent_dir)

            # folder_links: A list of files and their links to generate an
            #               index from if required (in file_detail format)
            folder_links = []

            # Place a link to the parent directory?
            if create_parent_links:
                filename = '../'
                full_path = os.path.normpath(os.path.join(path, filename))
                relative_name = os.path.relpath(full_path, parent_dir)
                if relative_name == '.':
                    # We are in a supplied folder currently
                    relative_name = ''
                    number_files = root_file_count
                else:
                    # We are in a subfolder
                    number_files = len(os.listdir(full_path))

                url = os.path.join(destination_prefix, relative_name)

                file_details = {
                    'filename': filename,
                    'path': full_path,
                    'relative_name': relative_name,
                    'url': url,
                    'metadata': get_folder_metadata(full_path, number_files),
                }

                folder_links.append(file_details)

            for f in sorted(folders, key=lambda x: x.lower()):
                filename = os.path.basename(f) + '/'
                full_path = os.path.join(path, filename)
                relative_name = os.path.relpath(full_path, parent_dir)
                url = os.path.join(destination_prefix, relative_name)
                number_files = len(os.listdir(full_path))

                file_details = {
                    'filename': filename,
                    'path': full_path,
                    'relative_name': relative_name,
                    'url': url,
                    'metadata': get_folder_metadata(full_path, number_files),
                }

                folder_links.append(file_details)

            for f in sorted(files, key=lambda x: x.lower()):
                filename = os.path.basename(f)
                full_path = os.path.join(path, filename)
                relative_name = os.path.relpath(full_path, parent_dir)
                url = os.path.join(destination_prefix, relative_name)

                file_details = {
                    'filename': filename,
                    'path': full_path,
                    'relative_name': relative_name,
                    'url': url,
                    'metadata': get_file_metadata(full_path),
                }

                file_list.append(file_details)
                folder_links.append(file_details)

            if create_dir_indexes:
                full_path = make_index_file(
                    folder_links,
                    "Index of %s" % os.path.join(swift_destination_prefix,
                                                 relative_path),
                    append_footer=append_footer
                )
                if full_path:
                    filename = os.path.basename(full_path)
                    relative_name = os.path.join(relative_path, filename)
                    url = os.path.join(destination_prefix, relative_name)

                    file_details = {
                        'filename': filename,
                        'path': full_path,
                        'relative_name': relative_name,
                        'url': url,
                    }

                    file_list.append(file_details)

    return file_list


class PostThread(threading.Thread):
    """Thread object to upload files to swift via form post"""
    def __init__(self, queue):
        super(PostThread, self).__init__()
        self.queue = queue

    def _post_file(self, url, payload, fileinfo, headers):
        if payload['expires'] < time.time():
            raise Exception("Ran out of time uploading files!")
        files = {}
        for key in fileinfo.keys():
            files[key] = (fileinfo[key][0],
                          open(fileinfo[key][1], 'rb'),
                          fileinfo[key][2])

        for attempt in xrange(3):
            try:
                requests.post(url, headers=headers, data=payload, files=files)
                break
            except requests.exceptions.RequestException:
                if attempt <= 3:
                    logging.exception(
                        "File posting error on attempt %d" % attempt)
                    continue
                else:
                    raise

    def run(self):
        while True:
            try:
                job = self.queue.get_nowait()
                logging.debug("%s: processing job %s",
                        threading.current_thread(),
                        job)
                self._post_file(*job)
            except requests.exceptions.RequestException:
                # Do our best to attempt to upload all the files
                logging.exception("Error posting file after multiple attempts")
                continue
            except IOError:
                # Do our best to attempt to upload all the files
                logging.exception("Error opening file")
                continue
            except Queue.Empty:
                # No more work to do
                return


def swift_form_post(queue, num_threads):
    """Spin up thread pool to upload to swift"""
    threads = []
    for x in range(num_threads):
        t = PostThread(queue)
        threads.append(t)
        t.start()
    for t in threads:
        t.join()


def expand_files(paths):
    """Expand the provided paths into a list of files/folders"""
    results = set()
    for p in paths:
        results.update(glob2.glob(p))
    return sorted(results, key=lambda x: x.lower())


def upload_from_args(args):
    """Upload all of the files and indexes"""
    # file_list: A list of files to push to swift (in file_detail format)
    file_list = []
    # folder_links: A list of files and their links to generate an
    #               index from if required (in file_detail format)
    folder_links = []

    try:
        logserver_prefix = os.environ['SWIFT_%s_LOGSERVER_PREFIX' % args.name]
        swift_destination_prefix = os.environ['LOG_PATH']
        swift_url = os.environ['SWIFT_%s_URL' % args.name]
        swift_hmac_body = os.environ['SWIFT_%s_HMAC_BODY' % args.name]
        swift_signature = os.environ['SWIFT_%s_SIGNATURE' % args.name]
    except KeyError as e:
        print 'Environment variable %s not found' % e
        quit()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
        # Set requests log level accordingly
        logging.getLogger("requests").setLevel(logging.DEBUG)
        logging.captureWarnings(True)

    destination_prefix = os.path.join(logserver_prefix,
                                      swift_destination_prefix)

    append_footer = args.append_footer
    if append_footer.lower() == 'none':
        append_footer = None

    for file_path in expand_files(args.files):
        file_path = os.path.normpath(file_path)
        if os.path.isfile(file_path):
            filename = os.path.basename(file_path)
            metadata = get_file_metadata(file_path)
        else:
            filename = os.path.basename(file_path) + '/'
            number_files = len(os.listdir(file_path))
            metadata = get_folder_metadata(file_path, number_files)

        url = os.path.join(destination_prefix, filename)
        file_details = {
            'filename': filename,
            'path': file_path,
            'relative_name': filename,
            'url': url,
            'metadata': metadata,
        }
        folder_links.append(file_details)

        file_list += build_file_list(
            file_path, logserver_prefix, swift_destination_prefix,
            (not (args.no_indexes or args.no_dir_indexes)),
            (not args.no_parent_links),
            len(args.files),
            append_footer=append_footer
        )

    index_file = ''
    if not (args.no_indexes or args.no_root_index):
        full_path = make_index_file(
            folder_links,
            "Index of %s" % swift_destination_prefix,
            append_footer=append_footer
        )
        if full_path:
            filename = os.path.basename(full_path)
            relative_name = filename
            url = os.path.join(destination_prefix, relative_name)

            file_details = {
                'filename': filename,
                'path': full_path,
                'relative_name': relative_name,
                'url': url,
            }

            file_list.append(file_details)

    logging.debug("List of files prepared to upload:")
    logging.debug(file_list)

    queue = swift_form_post_queue(file_list, swift_url, swift_hmac_body,
                                  swift_signature, args.delete_after)
    max_file_count = int(swift_hmac_body.split('\n')[3])
    # Attempt to upload at least one item
    items_to_upload = max(queue.qsize(), 1)
    # Cap number of threads to a reasonable number
    num_threads = min(max_file_count, items_to_upload)
    swift_form_post(queue, num_threads)

    logging.info(os.path.join(logserver_prefix, swift_destination_prefix,
                              os.path.basename(index_file)))

    return file_list


def create_folder_metadata_object(folder_hash, folder_name,
                                  destination_prefix=''):
    """Create a temp file with the folder metadata and return a file_detail
    dict
    """
    f, path = tempfile.mkstemp()
    # Serialise metadata as a json blob
    metadata = {'timestamp': time.time()}
    os.write(f, json.dumps(metadata))
    os.close(f)
    return {
        'filename': folder_hash,
        'path': path,
        'relative_name': folder_hash,
        'url': os.path.join(destination_prefix, folder_hash),
        'metadata': get_file_metadata(path),
    }


def build_metadata_object_list(file_list, destination_prefix=''):
    """Build a separate list of file_datils to be uploaded containing metadata.

    Only upload metadata for psuedo folders for now. Actual files can have
    their metadata stored directly in swift."""

    # key: hash of path, value: file_details (as above)
    object_list = {}
    for file_detail in file_list:
        # Grab each possible folder
        parts = file_detail['relative_name'].split('/')
        folder = ''
        for part in parts[:-1]:
            folder = '/'.join([folder, part])
            h = hashlib.sha1(folder).hexdigest()
            if h not in object_list.keys():
                object_list[h] = create_folder_metadata_object(
                    h, folder, destination_prefix)

    return object_list.values()


def cleanup_tmp_files(file_list):
    for f in file_list:
        if os.path.isfile(f['path']):
            os.unlink(f['path'])


def upload_metadata(file_list, args):
    try:
        logserver_prefix = os.environ['SWIFT_%s_LOGSERVER_PREFIX' %
                                      args.metadata]
        swift_url = os.environ['SWIFT_%s_URL' % args.metadata]
        swift_hmac_body = os.environ['SWIFT_%s_HMAC_BODY' % args.metadata]
        swift_signature = os.environ['SWIFT_%s_SIGNATURE' % args.metadata]
    except KeyError as e:
        print 'Environment variable %s not found' % e
        quit()

    metadata_objects = build_metadata_object_list(file_list, logserver_prefix)

    logging.debug("List of files prepared to upload:")
    logging.debug(metadata_objects)

    queue = swift_form_post_queue(metadata_objects, swift_url, swift_hmac_body,
                                  swift_signature, args.delete_after)
    max_file_count = int(swift_hmac_body.split('\n')[3])
    # Attempt to upload at least one item
    items_to_upload = max(queue.qsize(), 1)
    # Cap number of threads to a reasonable number
    num_threads = min(max_file_count, items_to_upload)
    swift_form_post(queue, num_threads)

    cleanup_tmp_files(metadata_objects)


def grab_args():
    """Grab and return arguments"""
    parser = argparse.ArgumentParser(
        description="Upload results to swift using instructions from zuul"
    )
    parser.add_argument('--verbose', action='store_true',
                        help='show debug information')
    parser.add_argument('--no-indexes', action='store_true',
                        help='do not generate any indexes at all')
    parser.add_argument('--no-root-index', action='store_true',
                        help='do not generate a root index')
    parser.add_argument('--no-dir-indexes', action='store_true',
                        help='do not generate a indexes inside dirs')
    parser.add_argument('--no-parent-links', action='store_true',
                        help='do not include links back to a parent dir')
    parser.add_argument('--append-footer', default='index_footer.html',
                        help='when generating an index, if the given file is '
                             'present in a folder, append it to the index '
                             '(set to "none" to disable)')
    parser.add_argument('-n', '--name', default="logs",
                        help='The instruction-set to use')
    parser.add_argument('-m', '--metadata', default=None,
                        help='The instruction-set to use for pseudo folder '
                             'metadata')
    parser.add_argument('--delete-after', default='15552000',
                        help='Number of seconds to delete object after '
                             'upload. Default is 6 months (15552000 seconds) '
                             'and if set to 0 X-Delete-After will not be set',
                        type=int)
    parser.add_argument('files', nargs='+',
                        help='the file(s) to upload with recursive glob '
                        'matching when supplied as a string')

    return parser.parse_args()


if __name__ == '__main__':
    # Avoid unactionable warnings
    requestsexceptions.squelch_warnings(requestsexceptions.InsecureRequestWarning)

    args = grab_args()

    uploaded_files = upload_from_args(args)
    if args.metadata:
        upload_metadata(uploaded_files, args)
