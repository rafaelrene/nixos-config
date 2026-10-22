import re
import subprocess
import sys
from pathlib import Path

# Remove these roots without dropping unrelated OpenSSL distrust attributes.
# https://emudhra.we-have-a-problem.com/roots.json
fingerprints = {
    "D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4",
    "86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B",
}
certificate = re.compile(
    rb"-----BEGIN (?P<label>(?:TRUSTED )?CERTIFICATE)-----.*?"
    rb"-----END (?P=label)-----",
    re.DOTALL,
)


def retain_unaffected(match: re.Match[bytes]) -> bytes:
    block = match.group()
    result = subprocess.run(
        ["openssl", "x509", "-noout", "-sha256", "-fingerprint"],
        input=block,
        capture_output=True,
        check=True,
    )
    fingerprint = result.stdout.decode().strip().split("=", 1)[1].replace(":", "")
    return b"" if fingerprint in fingerprints else block


for argument in sys.argv[1:]:
    bundle = Path(argument)
    filtered = certificate.sub(retain_unaffected, bundle.read_bytes())
    if not certificate.search(filtered):
        raise ValueError(f"Refusing an empty certificate bundle: {bundle}")
    bundle.write_bytes(filtered)
