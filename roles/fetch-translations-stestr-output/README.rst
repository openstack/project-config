Collect stestr output from translation jobs

This role collects only the testrepository.subunit file which has to
be compressed already.

**Role Variables**

.. zuul:rolevar:: zuul_work_dir
   :default: {{ zuul.project.src_dir }}

   Directory where ``testrepository.subunit.gz`` file is.

