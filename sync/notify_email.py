import os
import ssl
import smtplib
from email.message import EmailMessage
from pathlib import Path
import sys

def load_env_file(path: str) -> None:
    p = Path(path)
    if not p.exists():
        return
    for line in p.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip())

def main() -> int:
    # Load SMTP secrets from a mounted env file
    load_env_file("/run/secrets/smtp.env")

    host = os.environ.get("SMTP_HOST")
    port = int(os.environ.get("SMTP_PORT", "587"))
    user = os.environ.get("SMTP_USER")
    password = os.environ.get("SMTP_PASS")
    mail_from = os.environ.get("SMTP_FROM")
    mail_to = os.environ.get("SMTP_TO")

    if not all([host, user, password, mail_from, mail_to]):
        print("[notify] Missing SMTP env vars; cannot send email.", file=sys.stderr)
        return 2

    reason = sys.argv[1] if len(sys.argv) > 1 else "Unknown failure"

    msg = EmailMessage()
    msg["Subject"] = "beancount-pi: ledger sync FAILED"
    msg["From"] = mail_from
    msg["To"] = mail_to
    msg.set_content(
        "The nightly ledger sync on your Raspberry Pi failed.\n\n"
        f"Reason:\n{reason}\n"
    )

    context = ssl.create_default_context()

    with smtplib.SMTP(host, port, timeout=30) as smtp:
        smtp.ehlo()
        smtp.starttls(context=context)
        smtp.ehlo()
        smtp.login(user, password)
        smtp.send_message(msg)

    print("[notify] Email sent.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
