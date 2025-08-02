from flask import Flask
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)
tracer = trace.get_tracer(__name__)


@app.route("/health")
def health():
    return {"status": "ok"}


@app.route("/")
def index():
    with tracer.start_as_current_span("index"):
        return {"message": "Hello from ECS with OTel"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
