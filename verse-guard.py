#!/usr/bin/env python3
"""verse-guard - safe launch checker, prevents duplicate verse daemons.

Mode 1 (with command): Acquires lockfile, then execs into the command.
  The lock fd survives exec, so it's held for the child's entire lifetime.
  Usage: verse-guard <lockfile> <command> [args...]

Mode 2 (without command): Just checks the lock. Acquires if free, exits 0.
  Caller must hold the process or the lock is released.
  Usage: verse-guard <lockfile>

Exit codes:
  0 = lock acquired / safe to proceed
  1 = already running (lock held by another instance)
  2 = usage / exec error
"""

import fcntl
import os
import signal
import sys

fd = -1

def cleanup():
    global fd
    if fd >= 0:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)
        except OSError:
            pass
        fd = -1

def sig_handler(sig, frame):
    cleanup()
    sys.exit(0)

def try_acquire(lockfile):
    global fd
    try:
        fd = os.open(lockfile, os.O_CREAT | os.O_RDWR, 0o600)
    except OSError as e:
        print(f"verse-guard: cannot open lockfile {lockfile}: {e}", file=sys.stderr)
        return 2

    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        try:
            data = os.read(fd, 32).decode().strip()
            if data:
                other_pid = int(data)
                try:
                    os.kill(other_pid, 0)
                    print(f"verse-guard: verse is already running (pid {other_pid})", file=sys.stderr)
                    os.close(fd)
                    fd = -1
                    return 1
                except ProcessLookupError:
                    # stale lock — previous instance died; reclaim
                    fcntl.flock(fd, fcntl.LOCK_UN)
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (ValueError, OSError):
            pass

    os.ftruncate(fd, 0)
    os.write(fd, str(os.getpid()).encode())
    os.lseek(fd, 0, os.SEEK_SET)

    signal.signal(signal.SIGTERM, sig_handler)
    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGHUP, sig_handler)

    # make fd inheritable so the lock survives exec (mode 1)
    os.set_inheritable(fd, True)

    return 0

def main():
    args = sys.argv[1:]
    if len(args) < 1:
        print("Usage: verse-guard <lockfile> [command [args...]]", file=sys.stderr)
        return 2

    lockfile = args[0]
    rc = try_acquire(lockfile)
    if rc != 0:
        return rc

    if len(args) == 1:
        # check-only mode: release lock and exit (caller will spawn)
        cleanup()
        print(f"verse-guard: lock check passed")
        return 0

    # exec mode: keep lock fd open, exec into command
    command = args[1:]
    print(f"verse-guard: lock acquired (pid {os.getpid()}), execing {' '.join(command)}")
    os.execvp(command[0], command)
    # exec failed
    print(f"verse-guard: exec failed: {command[0]}", file=sys.stderr)
    cleanup()
    return 2

if __name__ == "__main__":
    rc = main()
    sys.exit(rc)
