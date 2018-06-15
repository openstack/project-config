Test building sdist and wheel for Python projects and verify their
metadata.

** Role Variables **

.. zuul:rolevar:: release_python
   :default: python

   The python interpreter to use. Set it to "python3" to use python 3,
   for example.

.. zuul:rolevar:: check_python_release_virtualenv
   :default: {{ansible_user_dir}}/.venv

   The location for the virtualenv used to install the tools needed to
   check the packaging metadata for the project.
