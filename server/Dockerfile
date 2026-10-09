FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# The production image (render.yaml) installs only what the server needs;
# docker-compose.yml builds with requirements-dev.txt for pytest.
ARG REQUIREMENTS=requirements.txt
COPY requirements.txt requirements-dev.txt ./
RUN pip install -r ${REQUIREMENTS}

COPY . .

RUN useradd --create-home --uid 1000 mizan
USER mizan

EXPOSE 8000

# Production: gunicorn with a fixed pool of threads, on the host's $PORT.
# docker-compose.yml runs the dev server instead.
CMD ["sh", "-c", "python manage.py migrate --noinput && exec gunicorn mizan.wsgi --bind 0.0.0.0:${PORT:-8000} --workers ${WEB_CONCURRENCY:-2} --threads 4 --timeout 60 --access-logfile -"]
