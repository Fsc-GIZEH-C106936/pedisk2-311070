#!/usr/bin/env python
'''
Check that each file assembles and that the output binary
is identical to the original file.
'''
import filecmp
import os
import subprocess
import shutil
import sys
import tempfile

FILES = {'dos_t00_s09_7800.asm':   'bin/dos_t00_s09_7800.bin',
         'dos_t00_s22_7a00.asm':   'bin/dos_t00_s22_7a00.bin',
         'dos_t00_s26_7c00_h.asm': 'bin/dos_t00_s26_7c00_h.bin',
         'dos_t01_s01_7c00_p.asm': 'bin/dos_t01_s01_7c00_p.bin',
         'dos_t01_s05_7c00_u.asm': 'bin/dos_t01_s05_7c00_u.bin',
         'dos_t01_s07_7c00_4.asm': 'bin/dos_t01_s07_7c00_4.bin',
         'dos_t01_s09_7c00_3.asm': 'bin/dos_t01_s09_7c00_3.bin',
         'dos_t01_s15_7c00_2.asm': 'bin/dos_t01_s15_7c00_2.bin',
         'dos_t01_s19_7c00_1.asm': 'bin/dos_t01_s19_7c00_1.bin',
         'dos_t01_s25_7c00_d.asm': 'bin/dos_t01_s25_7c00_d.bin',
         'dos_t01_s28_7c00_n.asm': 'bin/dos_t01_s28_7c00_n.bin',
         'pedisk2.asm':            'bin/pedisk2.bin'
        }

def main():
    repo_root = os.path.abspath(os.path.join(__file__, ".."))

    failures = []
    for src in sorted(FILES.keys()):
        # find absolute path to original binary, if any
        original = FILES[src]
        if original is not None:
            original = os.path.join(repo_root, FILES[src])

        # change to directory of source file
        # this is necessary for files that use include directives
        src_dirname = os.path.join(repo_root, os.path.dirname(src))
        os.chdir(src_dirname)

        # filenames for assembly command
        tmpdir = tempfile.mkdtemp(prefix='pedisk2')
        srcfile = os.path.join(repo_root, src)
        outfile = os.path.join(tmpdir, 'a.bin')
        subs = {'srcfile': srcfile, 'outfile': outfile}

        # assembler command
        cmd = "acme -v1 --cpu 6502 -o '%(outfile)s' '%(srcfile)s'"

        # try to assemble the file
        try:
            subprocess.check_output(cmd % subs, shell=True)
            assembled = True
        except subprocess.CalledProcessError as exc:
            sys.stdout.write(exc.output)
            assembled = False

        # check assembled output is identical to original binary
        if not assembled:
            sys.stderr.write("%s: assembly failed\n" % src)
            failures.append(src)
        elif original is None:
            sys.stdout.write("%s: ok\n" % src)
        elif filecmp.cmp(original, outfile):
            sys.stdout.write("%s: ok\n" % src)
        else:
            sys.stderr.write("%s: not ok\n" % src)
            failures.append(src)

        shutil.rmtree(tmpdir)

    return len(failures)

if __name__ == '__main__':
    if sys.version_info[:2] < (2, 7):
        sys.stderr.write("Python 2.7 or later required\n")
        sys.exit(1)

    status = main()
    sys.exit(status)
