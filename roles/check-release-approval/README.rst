Query Gerrit on release requests, checking for approvals from the PTL or
release liaison corresponding to the affected deliverable. Succeed if such
approval is present, fail otherwise.

**Role Variables**

.. zuul:rolevar:: change

   Gerrit change number. Should be something like: 696104

.. zuul:rolevar:: releases

   Directory containing the releases repository data.

.. zuul:rolevar:: governance

   Directory containing the governance repository data.
