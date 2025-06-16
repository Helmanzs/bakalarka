#!/usr/bin/env python3
import os
import sys
import subprocess
import tempfile
from itertools import islice

def import_in_chunks(data_file, chunk_size, tsdb_cmd):
    """
    Read `data_file` in chunks of `chunk_size` lines, dump each to a
    temp file, and call `tsdb_cmd import <tempfile>` on it.
    """
    with open(data_file, 'r') as f:
        chunk_index = 0
        while True:
            lines = list(islice(f, chunk_size))
            if not lines:
                break

            # write chunk to a temp file
            with tempfile.NamedTemporaryFile(mode='w+', delete=False) as tmp:
                tmp.write(''.join(lines))
                tmp.flush()
                tmp_path = tmp.name

            # import that temp file
            result = subprocess.run(
                [tsdb_cmd, 'import', tmp_path],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
            )
            # clean up the temp file
            os.unlink(tmp_path)

            if result.returncode != 0:
                sys.stderr.write(result.stderr)
                sys.exit(f"tsdb import failed on chunk {chunk_index}")

            chunk_index += 1

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <data_file> <chunk_size> <tsdb_cmd>")
        sys.exit(1)

    data_file, chunk_size, tsdb_cmd = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    import_in_chunks(data_file, chunk_size, tsdb_cmd)
