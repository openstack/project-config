Upload logs to a static webserver

This uploads logs to a static webserver using SSH.

**Role Variables**

.. zuul:rolevar:: zuul_log_url

   Base URL where logs are to be found.

.. zuul:rolevar:: zuul_logserver_root
   :default: /srv/static/logs

   The root path to the logs on the logserver.

.. zuul:rolevar:: zuul_site_upload_logs
   :default: true

   Controls when logs are uploaded. true, the default, means always upload
   logs. false means never upload logs. 'failure' means to only upload logs
   when the job has failed.

   .. note:: Intended to be set by admins via site-variables.
