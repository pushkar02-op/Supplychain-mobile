import os


def read_logs():
    try:
        with open("backend_logs.txt", "r", encoding="utf-16le") as f:
            lines = f.readlines()
            for line in lines[-100:]:
                print(line.strip())
    except Exception as e:
        print(f"Error reading utf-16le: {e}")
        # Try default encoding
        try:
            with open("backend_logs.txt", "r") as f:
                lines = f.readlines()
                for line in lines[-100:]:
                    print(line.strip())
        except Exception as e2:
            print(f"Error reading default: {e2}")


if __name__ == "__main__":
    read_logs()
