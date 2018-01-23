Collect subunit output from translation jobs

This role collects only the testrepository.subunit file which has
already been compressed. The common_translation_update.sh script
uses generate-subunit to create a subunit file containing success or
failure, thus :zuul:role:`fetch-subunit-output` is not appropriate.

**Role Variables**

.. zuul:rolevar:: zuul_work_dir
   :default: {{ zuul.project.src_dir }}

   Directory where ``testrepository.subunit.gz`` file is.

