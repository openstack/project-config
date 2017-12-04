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
   :default: 3.8.1

  The version of zanata client to install

.. zuul:rolevar:: zanata_client_checksum
   :default: cc4ecfa2d530ff314076bd0173bdf829824737d48d4f4a2f4ca18d263e9da7c3

  The expected SHA256 checksum of the zanata client
