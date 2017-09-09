Submit a log processing job to the logstash workers.

This role examines all of the files in the log subdirectory of the job
work dir and any matching filenames are submitted to the gearman queue
for the logstash log processor, along with any tags configured for
those filenames.

**Role Variables**

.. zuul:rolevar:: logstash_gearman_server
   :default: logstash.openstack.org

   The gearman server to use.

.. zuul:rolevar:: logstash_processor_config
   :type: dict

   The default file configuration for the logstash parser.

   This is a dictionary that contains a single entry:

   .. zuul:rolevar:: files
      :type: list

      A list of files to search for in the ``work/logs/`` directory on
      the executor.  Each file will be compared to the entries in this
      list, and if it matches, a processing job will be submitted to
      the logstash processing queue, along with the tags for the
      matching entry.  Order is important: the first matcing is used.
      This field is list of dictionaries, as follows:

      .. zuul:rolevar:: name

         The name of the file to process.  This is treated as an
         unanchored regular expression.  To match the full path
         (underneath ``work/logs``) start and end the string with
         ``^`` and ``$`` respectively.

      .. zuul:rolevar:: tags
         :type: list

         A list of strings indicating the logstash processing tags
         associated with this file.  These may be used to indicate the
         file format to the parser.
