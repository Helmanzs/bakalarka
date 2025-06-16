import subprocess
import glob
import os
import sys

def upload_chunk(filepath):
    print(f"Uploading {filepath}")
    cmd = [
        "/usr/share/opentsdb/bin/tsdb",
        "import",
        filepath
    ]
    subprocess.run(cmd, check=True)

def main():
    data_dir = "/tmp/opentsdb_chunks"
    if len(sys.argv) > 1:
        data_dir = sys.argv[1]
    
    files = sorted(glob.glob(os.path.join(data_dir, "chunk_*.gz")))
    for f in files:
        upload_chunk(f)

if __name__ == "__main__":
    main()
