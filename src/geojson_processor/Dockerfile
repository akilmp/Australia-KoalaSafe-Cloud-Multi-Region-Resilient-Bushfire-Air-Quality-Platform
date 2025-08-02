FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends gdal-bin libgdal-dev libgeos-dev && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir boto3 fiona shapely

WORKDIR /app
COPY main.py /app/main.py

ENTRYPOINT ["python", "main.py"]
