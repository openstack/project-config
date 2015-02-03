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
import magic
import os
import requests
import stat
import sys
import tempfile
import time


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


def generate_log_index(folder_links, header_message=''):
    """Create an index of logfiles and links to them"""

    output = '<html><head><title>Index of results</title></head><body>\n'
    output += '<h1>%s</h1>\n' % header_message
    output += '<table><tr><th>Name</th><th>Last Modified</th><th>Size</th>'
    output += '<th>Mime</th></tr>\n'

    for file_details in folder_links:
        output += '<tr>'
        output += '<td><a href="%s">%s</a></td>' % (file_details['url'],
                                                    file_details['filename'])
        output += '<td>%s</td>' % time.asctime(
            file_details['metadata']['last_modified'])
        if file_details['metadata']['mime'] == 'folder':
            size = str(file_details['metadata']['size'])
        else:
            size = sizeof_fmt(file_details['metadata']['size'])
        output += '<td>%s</td>' % size
        output += '<td><em>%s</em></td>' % file_details['metadata']['mime']

        output += '</tr>\n'

    output += '</table>'
    output += '</body></html>\n'
    return output


def make_index_file(folder_links, header_message='',
                    index_filename='index.html'):
    """Writes an index into a file for pushing"""

    index_content = generate_log_index(folder_links, header_message)
    tempdir = tempfile.mkdtemp()
    fd = open(os.path.join(tempdir, index_filename), 'w')
    fd.write(index_content)
    return os.path.join(tempdir, index_filename)


def sizeof_fmt(num, suffix='B'):
    # From http://stackoverflow.com/questions/1094841/
    # reusable-library-to-get-human-readable-version-of-file-size
    for unit in ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)


def get_file_mime(file_path):
    """Get the file mime using libmagic"""

    if not os.path.isfile(file_path):
        return None

    if hasattr(magic, 'from_file'):
        return magic.from_file(file_path, mime=True)
    else:
        # no magic.from_file, we might be using the libmagic bindings
        m = magic.open(magic.MAGIC_MIME)
        m.load()
        return m.file(file_path).split(';')[0]


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


def swift_form_post_submit(file_list, url, hmac_body, signature):
    """Send the files to swift via the FormPost middleware"""

    # We are uploading the file_list as an HTTP POST multipart encoded.
    # First grab out the information we need to send back from the hmac_body
    payload = {}

    (object_prefix,
     payload['redirect'],
     payload['max_file_size'],
     payload['max_file_count'],
     payload['expires']) = hmac_body.split('\n')
    payload['signature'] = signature

    # Loop over the file list in chunks of max_file_count
    for sub_file_list in (file_list[pos:pos + int(payload['max_file_count'])]
                          for pos in xrange(0, len(file_list),
                                            int(payload['max_file_count']))):
        if payload['expires'] < time.time():
            raise Exception("Ran out of time uploading files!")
        files = {}
        # Zuul's log path is sometimes generated without a tailing slash. As
        # such the object prefix does not contain a slash and the files would
        # be  uploaded as 'prefix' + 'filename'. Assume we want the destination
        # url to look like a folder and make sure there's a slash between.
        filename_prefix = '/' if url[-1] != '/' else ''
        for i, f in enumerate(sub_file_list):
            if os.path.getsize(f['path']) > int(payload['max_file_size']):
                sys.stderr.write('Warning: %s exceeds %d bytes. Skipping...\n'
                                 % (f['path'], int(payload['max_file_size'])))
                continue
            files['file%d' % (i + 1)] = (filename_prefix + f['relative_name'],
                                         open(f['path'], 'rb'),
                                         get_file_mime(f['path']))
        requests.post(url, data=payload, files=files)


def build_file_list(file_path, logserver_prefix, swift_destination_prefix,
                    create_dir_indexes=True, create_parent_links=True,
                    root_file_count=0):
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

            for f in sorted(folders):
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

            for f in sorted(files):
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
                                                 relative_path)
                )
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


def grab_args():
    """Grab and return arguments"""
    parser = argparse.ArgumentParser(
        description="Upload results to swift using instructions from zuul"
    )
    parser.add_argument('--no-indexes', action='store_true',
                        help='do not generate any indexes at all')
    parser.add_argument('--no-root-index', action='store_true',
                        help='do not generate a root index')
    parser.add_argument('--no-dir-indexes', action='store_true',
                        help='do not generate a indexes inside dirs')
    parser.add_argument('--no-parent-links', action='store_true',
                        help='do not include links back to a parent dir')
    parser.add_argument('-n', '--name', default="logs",
                        help='The instruction-set to use')
    parser.add_argument('files', nargs='+', help='the file(s) to upload')

    return parser.parse_args()


if __name__ == '__main__':
    args = grab_args()
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

    destination_prefix = os.path.join(logserver_prefix,
                                      swift_destination_prefix)

    for file_path in args.files:
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
            len(args.files)
        )

    index_file = ''
    if not (args.no_indexes or args.no_root_index):
        full_path = make_index_file(
            folder_links,
            "Index of %s" % swift_destination_prefix
        )
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

    swift_form_post_submit(file_list, swift_url, swift_hmac_body,
                           swift_signature)

    print os.path.join(logserver_prefix, swift_destination_prefix,
                       os.path.basename(index_file))
