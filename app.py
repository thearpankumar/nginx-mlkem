from flask import Flask, request

app = Flask(__name__)

@app.route('/')
def index():
    # Log all headers for debugging
    headers = dict(request.headers)
    print("Received Headers:", headers)

    # Get the TLS version from the custom header set by Nginx
    tls_version = request.headers.get('X-Ssl-Protocol', 'Unknown')  # Updated header name

    # Check if the request is using TLS 1.3
    is_tls_1_3 = tls_version == 'TLSv1.3'

    # Get the SSL curve from the custom header set by Nginx
    ssl_curve = request.headers.get('X-Ssl-Curve', 'Unknown')  # Updated header name

    # Check if the curve is an MLKEM curve
    ecdh_curves = {
    "frodo640aes": 65024,
    "p256_frodo640aes": 0x2F00,
    "x25519_frodo640aes": 0x2F80,
    "frodo640shake": 65025,
    "p256_frodo640shake": 0x2F01,
    "x25519_frodo640shake": 0x2F81,
    "frodo976aes": 65026,
    "p384_frodo976aes": 0x2F02,
    "x448_frodo976aes": 0x2F82,
    "frodo976shake": 0x0203,
    "p384_frodo976shake": 0x2F03,
    "x448_frodo976shake": 0x2F83,
    "frodo1344aes": 0x0204,
    "p521_frodo1344aes": 0x2F04,
    "frodo1344shake": 0x0205,
    "p521_frodo1344shake": 0x2F05,
    "mlkem512": 512,
    "p256_mlkem512": 0x2F4B,
    "x25519_mlkem512": 0x2FB6,
    "mlkem768": 513,
    "p384_mlkem768": 0x2F4C,
    "x448_mlkem768": 0x2FB7,
    "X25519MLKEM768": 0x11ec,
    "SecP256r1MLKEM768": 0x11eb,
    "mlkem1024": 514,
    "p521_mlkem1024": 0x2F4D,
    "SecP384r1MLKEM1024": 0x11ED,
    "bikel1": 0x0241,
    "p256_bikel1": 0x2F41,
    "x25519_bikel1": 0x2FAE,
    "bikel3": 0x0242,
    "p384_bikel3": 0x2F42,
    "x448_bikel3": 0x2FAF,
    "bikel5": 0x0243,
    "p521_bikel5": 0x2F43,
    "hqc128": 0x0244,
    "p256_hqc128": 0x2F44,
    "x25519_hqc128": 0x2FB0,
    "hqc192": 0x0245,
    "p384_hqc192": 0x2F45,
    "x448_hqc192": 0x2FB1,
    "hqc256": 0x0246,
    "p521_hqc256": 0x2F46,
    "mldsa44": 0x0904,
    "p256_mldsa44": 0xff06,
    "rsa3072_mldsa44": 0xff07,
    "mldsa44_pss2048": 0x090f,
    "mldsa44_rsa2048": 0x090c,
    "mldsa44_ed25519": 0x090a,
    "mldsa44_p256": 0x0907,
    "mldsa44_bp256": 0xfee5,
    "mldsa65": 0x0905,
    "p384_mldsa65": 0xff08,
    "mldsa65_pss3072": 0x0910,
    "mldsa65_rsa3072": 0x090d,
    "mldsa65_p256": 0x0908,
    "mldsa65_bp256": 0xfee9,
    "mldsa65_ed25519": 0x090b,
    "mldsa87": 0x0906,
    "p521_mldsa87": 0xff09,
    "mldsa87_p384": 0x0909,
    "mldsa87_bp384": 0xfeec,
    "mldsa87_ed448": 0x0912,
    "falcon512": 0xfed7,
    "p256_falcon512": 0xfed8,
    "rsa3072_falcon512": 0xfed9,
    "falconpadded512": 0xfedc,
    "p256_falconpadded512": 0xfedd,
    "rsa3072_falconpadded512": 0xfede,
    "falcon1024": 0xfeda,
    "p521_falcon1024": 0xfedb,
    "falconpadded1024": 0xfedf,
    "p521_falconpadded1024": 0xfee0,
    "sphincssha2128fsimple": 0xfeb3,
    "p256_sphincssha2128fsimple": 0xfeb4,
    "rsa3072_sphincssha2128fsimple": 0xfeb5,
    "sphincssha2128ssimple": 0xfeb6,
    "p256_sphincssha2128ssimple": 0xfeb7,
    "rsa3072_sphincssha2128ssimple": 0xfeb8,
    "sphincssha2192fsimple": 0xfeb9,
    "p384_sphincssha2192fsimple": 0xfeba,
    "sphincssha2192ssimple": 0xfebb,
    "p384_sphincssha2192ssimple": 0xfebc,
    "sphincssha2256fsimple": 0xfebd,
    "p521_sphincssha2256fsimple": 0xfebe,
    "sphincssha2256ssimple": 0xfec0,
    "p521_sphincssha2256ssimple": 0xfec1,
    "sphincsshake128fsimple": 0xfec2,
    "p256_sphincsshake128fsimple": 0xfec3,
    "rsa3072_sphincsshake128fsimple": 0xfec4,
    "sphincsshake128ssimple": 0xfec5,
    "p256_sphincsshake128ssimple": 0xfec6,
    "rsa3072_sphincsshake128ssimple": 0xfec7,
    "sphincsshake192fsimple": 0xfec8,
    "p384_sphincsshake192fsimple": 0xfec9,
    "sphincsshake192ssimple": 0xfeca,
    "p384_sphincsshake192ssimple": 0xfecb,
    "sphincsshake256fsimple": 0xfecc,
    "p521_sphincsshake256fsimple": 0xfecd,
    "sphincsshake256ssimple": 0xfece,
    "p521_sphincsshake256ssimple": 0xfecf,
    "mayo1": 0xfeee,
    "p256_mayo1": 0xfef2,
    "mayo2": 0xfeef,
    "p256_mayo2": 0xfef3,
    "mayo3": 0xfef0,
    "p384_mayo3": 0xfef4,
    "mayo5": 0xfef1,
    "p521_mayo5": 0xfef5,
    "CROSSrsdp128balanced": 0xfef6,
    "CROSSrsdp128fast": 0xfef7,
    "CROSSrsdp128small": 0xfef8,
    "CROSSrsdp192balanced": 0xfef9,
    "CROSSrsdp192fast": 0xfefa,
    "CROSSrsdp192small": 0xfefb,
    "CROSSrsdp256small": 0xfefc,
    "CROSSrsdpg128balanced": 0xfefd,
    "CROSSrsdpg128fast": 0xfefe,
    "CROSSrsdpg128small": 0xfeff,
    "CROSSrsdpg192balanced": 0xff00,
    "CROSSrsdpg192fast": 0xff01
}

    try:
        ssl_curve_int = int(ssl_curve, 16)  # Convert hex string to integer
    except (ValueError, TypeError):
        ssl_curve_int = None  # Handle invalid or missing values

    # Check if the curve is an MLKEM curve
    is_mlkem = ssl_curve_int in mlkem_curves.values()

    # Get the algorithm name for the curve
    key_name = next(
        (key for key, value in mlkem_curves.items() if value == ssl_curve_int),
        "Unknown"
    )

    # Prepare the response
    response = (
        f"<h1>TLS 1.3 and MLKEM Check</h1>"
        f"<p><strong>TLS Version:</strong> {tls_version}</p>"
        f"<p><strong>Is TLS 1.3:</strong> {is_tls_1_3}</p>"
        f"<p><strong>SSL Curve:</strong> {ssl_curve} (algorithm name = {key_name})</p>"
        f"<p><strong>Is MLKEM Curve:</strong> {is_mlkem}</p>"
        f"<h2>All Headers:</h2>"
        f"<pre>{headers}</pre>"
    )

    return response

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
