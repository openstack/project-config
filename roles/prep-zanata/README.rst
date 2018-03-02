Prepare zanata client use

**Role Variables**

.. zuul:rolevar:: zanata_api_credentials

  Complex argument which contains the ssh key information. It is
  expected that this argument comes from a `Secret`

    .. zuul:rolevar:: server_id

        This is the ID of the zanata server to use

    .. zuul:rolevar:: url

        The url to the zanata server

    .. zuul:rolevar:: username

        The username to use with the zanata server

    .. zuul:rolevar:: key

        The key to login with

.. zuul:rolevar:: zanata_client_version
   :default: 4.3.3

  The version of zanata client to install

.. zuul:rolevar:: zanata_client_checksum
   :default: 25368516c2c6b94a8ad3397317abf69c723f3ba47a4f0357a31a1e075dd6f810

  The expected SHA256 checksum of the zanata client
