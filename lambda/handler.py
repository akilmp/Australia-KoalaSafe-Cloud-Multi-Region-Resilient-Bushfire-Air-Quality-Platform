from opentelemetry import trace
from opentelemetry.instrumentation.awslambda import AwsLambdaInstrumentor

# Instrument the Lambda handler
AwsLambdaInstrumentor().instrument()

tracer = trace.get_tracer(__name__)


def handler(event, context):
    """Sample Lambda handler instrumented with AWS Distro for OpenTelemetry."""
    with tracer.start_as_current_span("process_event"):
        message = event.get("message", "Hello from KoalaSafe")
        return {"statusCode": 200, "body": message}
