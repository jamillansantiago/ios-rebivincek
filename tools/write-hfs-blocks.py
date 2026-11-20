#!/usr/bin/env python3
"""Write only the 4 KiB blocks that differ between two images to the phone's userdata.

  python3 tools/write-hfs-blocks.py OLD.img NEW.img [device]

OLD is a copy of /dev/block/mmcblk0p50 pulled while the phone was in OrangeFox,
NEW is the same image after editing with hfsplus. Both must be the same size.
Contiguous runs of changed blocks are grouped and sent to the device with
`adb shell dd ... conv=notrunc`, so nothing outside those runs is touched.
"""
import os, subprocess, sys

BS = 4096


def runs(old, new):
    a, b = open(old, 'rb'), open(new, 'rb')
    size = os.path.getsize(old)
    assert size == os.path.getsize(new), 'image sizes differ'
    start = None
    for i in range(size // BS):
        x, y = a.read(BS), b.read(BS)
        if x != y:
            if start is None:
                start = i
        elif start is not None:
            yield start, i - start
            start = None
    if start is not None:
        yield start, size // BS - start
    a.close(); b.close()


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    old, new = sys.argv[1:3]
    dev = sys.argv[3] if len(sys.argv) > 3 else '/dev/block/mmcblk0p50'
    changed = list(runs(old, new))
    blocks = sum(n for _, n in changed)
    print(f'{len(changed)} runs, {blocks} blocks ({blocks * BS / 1048576:.1f} MiB)')
    src = open(new, 'rb')
    for start, count in changed:
        src.seek(start * BS)
        data = src.read(count * BS)
        cmd = ['adb', 'shell', f'dd of={dev} bs={BS} seek={start} count={count} conv=notrunc']
        p = subprocess.run(cmd, input=data, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if p.returncode:
            sys.exit(f'failed at block {start}: {p.stdout.decode(errors="replace")}')
        print(f'  wrote {start}..{start + count - 1}')
    src.close()
    print('done')


main()
