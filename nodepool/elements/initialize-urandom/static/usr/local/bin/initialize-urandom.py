#!/usr/bin/env python

# Copyright 2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import ctypes
import errno
import fcntl
import os
import struct
import subprocess

"""Add entropy to the kernel until the nonblocking pool is
initialized.

The Linux kernel has 3 entropy pools: input, blocking, and
nonblocking.  Normally entropy accumulates in the input pool and as it
is depleted by the other pools, it is transferred from the input pool
to the others.

The blocking pool corresponds to /dev/random, where reads from that
device return random numbers only as long as there is sufficient
entropy in the blocking pool.  When that entropy is depleted, further
reads from /dev/random block until it is replenished.

The nonblocking pool corresponds to /dev/urandom, where reads never
block.  Even if there is no entropy in the nonblocking pool, random
numbers are still returned.

The algorithms in use in Linux 3.17 require 128 bits of entropy in
order to initialize the random number generators associated with each
pool.  Naturally, reads from /dev/random will not return until the
associated generator is initialized.  Reads from /dev/urandom will not
block -- even if the generator is not initialized.  The kernel will
output a notice[1] if this happens.

In order to avoid the situation where urandom is used when
uninitialized, the kernel diverts entropy from timers and interrupts
to the nonblocking pool (instead of the input pool) until it is
initialized.  In this way, as the system boots, the nonblocking pool
accumulates entropy first, reducing the time period during which
urandom might produce numbers from an uninitialized generator, and
then the input and blocking pools are filled.

Beginning with Linux 3.17, the getrandom(2) syscall was added[2] so
that user-space programs that generally would like to use /dev/urandom
can do so without opening a file descriptor and, more relevant here,
can ensure that they do so only after the generator is initialized
(which otherwise is not possible with the /dev/urandom interface).

Unfortunately, programs which use this interface during early boot may
need to wait some time for the nonblocking pool to accumulate enough
entropy to initialize, and therefore for getrandom to return.
Particularly in the case of a VM, this may take considerable time.

There are many methods of addressing this shortcoming:

* Store data from /dev/random at shutdown and use it to seed the
  entropy pool at the next boot.  Most GNU/Linux distributions do
  this.  On Ubuntu Xenial, this task is performed by systemd[3].
  Unfortunately, while writes to /dev/random (which is the method
  systemd uses to seed the system at boot) do add data to the pool,
  they do not increase the internal tracking of the amount of entropy
  in the pool.  Therefore, for the purposes of determining whether the
  nonblocking pool has accumulated 128 bits of entropy, they are not
  counted.

* Use haveged to maintain a sufficient amount of entropy.  Haveged can
  produce entropy very quickly, and when run at boot, will typically
  immediately fill the entropy pool.  Haveged performs an ioctl
  operation on /dev/random rather than writing data to it, and this
  ioctl allows it to specify how much entropy the data it supplies
  contains.  Therefore, unlike writes to /dev/random, ioctls do
  increment the entropy counter.  Unfortunately, data from ioctls are
  *always* directed to the input pool.  While entropy from timers and
  interrupts are diverted to the nonblocking pool to speed its
  initialization, data arriving from the ioctl instead end up in the
  input pool for later use.

  When more entropy than is needed is supplied to the input pool, the
  kernel will preemptively transfer some of that entropy to the
  secondary (including nonblocking) pools.  Since haveged supplies so
  much data on startup, some of this entropy should be able to spill
  over into the nonblocking pool to aid it in achieving the
  initialization threshold.  Unfortunately, at the stage of early boot
  we are considering, the input pool's generator also has not been
  initialized.  When the kernel receives a large amount of data from
  haveged over the ioctl, it pushes the input pool's generator over
  the 128 bit threshold, and initializes the input pool's generator.
  When a pool's generator is initialized, the entropy counter for that
  pool is reset to zero.  This leaves no entropy to spill over to the
  nonblocking pool.  Haveged is only able to see the entropy count for
  the input pool, and therefore is unaware that further contributions
  of entropy would aid (via spill-over) in seeding the nonblocking
  pool.

  At this point it's worth discussing why the nonblocking pool is
  still not initialized despite a full input pool.  When a secondary
  pool needs more entropy, it can pull from the input pool.  However,
  there is a timer that only allows the nonblocking pool to withdraw
  entropy from the input pool every 60 seconds by default (this can be
  adjusted via proc).  If something during very early boot reads data
  from /dev/urandom, a transfer (from the very likely empty) input
  pool is initiated, starting the timer that will prevent another
  transfer for 60 seconds, even if the input pool is later filled
  (such as by haveged).  This means that even with haveged running at
  boot the delay due to a blocking getrandom(2) call may still be as
  long as 60 seconds.

* Use rng-tools for the same purpose as haveged.  rng-tools operates
  in a similar manner to haveged, supplying entropic data to the
  kernel via ioctl.  However, it does so in smaller chunks.  This
  means that once the input pool's generator surpasses the 128 bit
  threshold for initialization, entropy from the next ioctl from
  rng-tools will be available to spill over to the nonblocking pool,
  and may be sufficient to initialize it.

  Because of this behavior, use of rng-tools may cause getrandom(2) to
  return more quickly at boot, however, this may only happen due to a
  quirk of implementation and relies on some specific values and
  conditions for the amount of entropy in the input pool at the time
  it is run.

This program speeds initialization of the nonblocking pool by adding
entropy to the input pool in small chunks.  To determine when the
nonblocking pool is initialized, it performs the nonblocking
getrandom(2) syscall requesting one byte of random data.  As long as
the nonblocking pool is uninitialized, that call will fail and set
errno to EAGAIN.  In that case, the program reads 64 bytes of data
from haveged and sends it to the kernel using the ioctl interface,
then repeats this in a loop.  That will cause entropy to accumulate in
the input pool until it is initialized and reaches the spill-over
threshold.  Further data will accumulate in the nonblocking pool until
it is initialized.  Once that occurs, the getrandom(2) call will
return successfully, and the program will exit the loop.

There are other ways this problem could be addressed (changes to
haveged or rng-tools to support behavior like this, or changes to the
kernel to direct entropy received via ioctl to the nonblocking pool
during initialization), however, this problem is likely to be
short-lived as the nonblocking generator is being replaced[4] in
current kernel versions and should not suffer from the same problem.

[1] http://lxr.free-electrons.com/source/drivers/char/random.c?v=3.17#L1385
[2] https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/\
?id=c6e9d6f38894798696f23c8084ca7edbf16ee895
[3] https://www.freedesktop.org/software/systemd/man/systemd-random-seed.\
service.html
[4] https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/\
?id=e192be9d9a30555aae2ca1dc3aad37cba484cd4a
"""


class GeneratorNotInitializedError(Exception):
    pass


class InterruptedError(Exception):
    pass


class Pump(object):
    # How much data, in bytes, to move at once.  64 is the size of the
    # internal kernel buffer, so we match it.
    CHUNK_SIZE = 64

    # The syscall number for getrandom(2).
    SYS_getrandom = 318

    # The IOCTL to add entropy.
    OP_RNDADDENTROPY = 0x40085203

    # Flags for getrandom:
    GRND_NONBLOCK = 0x0001  # Do not block
    GRND_RANDOM = 0x0002  # Use /dev/random instead of urandom

    def __init__(self):
        # Use ctypes to invoke getrandom since it is not available in
        # python.  os.urandom may call getrandom in some versions of
        # python3, however, the blocking on initialization behavior is
        # seen as a bug and so os.urandom will never block, even if
        # getrandom would. See http://bugs.python.org/issue26839
        self._getrandom = ctypes.CDLL(None, use_errno=True).syscall
        self._getrandom.restype = ctypes.c_long
        # The arguments are syscall number, void *buf,
        # size_t buflen, unsigned int flags.
        self._getrandom.argtypes = (ctypes.c_long, ctypes.c_void_p,
                                    ctypes.c_size_t, ctypes.c_uint)

    def getrandom(self, length, random=False, nonblock=False):
        flags = 0
        if random:
            flags |= self.GRND_RANDOM
        if nonblock:
            flags |= self.GRND_NONBLOCK
        buf = ctypes.ARRAY(ctypes.c_char, length)()
        r = self._getrandom(self.SYS_getrandom, buf, len(buf), flags)
        if r == -1:
            err = ctypes.get_errno()
            if err == errno.EINVAL:
                raise Exception("getrandom: Invalid argument")
            elif err == errno.EFAULT:
                raise Exception("getrandom: Buffer is outside "
                                "accessible address space")
            elif err == errno.EAGAIN:
                raise GeneratorNotInitializedError()
            elif err == errno.EINTR:
                raise InterruptedError()
        return buf[:r]

    def isInitialized(self):
        # Read one byte from getrandom to determine whether the
        # nonblocking pool is initialized.
        try:
            r = self.getrandom(1, nonblock=True)
            if len(r) != 1:
                raise Exception("No data returned from getrandom")
            print("Nonblocking pool initialized")
            return True
        except GeneratorNotInitializedError:
            return False

    def run(self):
        """Move data from haveged to the kernel until the nonblocking pool is
        initialized.

        """
        if self.isInitialized():
            return

        random_fd = os.open('/dev/random', os.O_RDWR)
        # Start haveged and tell it to supply unlimited data on
        # stdout, and print summary information.
        p = subprocess.Popen(['/usr/sbin/haveged', '-f', '-', '-n', '0',
                              '-v', '1'],
                             stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        while not self.isInitialized():
            # Read a chunk from haveged.
            data = b''
            while len(data) < self.CHUNK_SIZE:
                data += p.stdout.read(self.CHUNK_SIZE - len(data))
            # The data structure is:
            # struct rand_pool_info {
            #        int     entropy_count;
            #        int     buf_size;
            #        __u32   buf[0];
            # };
            arg = struct.pack('iis', len(data) * 8, len(data), data)
            print("Moving %s bytes" % len(data))
            fcntl.ioctl(random_fd, self.OP_RNDADDENTROPY, arg)
        # Now that the generator is initialized, stop haveged and
        # print the summary information.
        p.send_signal(2)
        p.stdout.read()
        print(p.stderr.read().decode('utf-8'))


if __name__ == '__main__':
    p = Pump()
    p.run()
