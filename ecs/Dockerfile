FROM public.ecr.aws/docker/library/python:3.12-slim
WORKDIR /app
COPY app.py /app/
RUN pip install --no-cache-dir flask opentelemetry-sdk opentelemetry-instrumentation-flask aws-distro-opentelemetry
CMD ["opentelemetry-instrument", "python", "app.py"]
