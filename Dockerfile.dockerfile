FROM python:3.11-slim

WORKDIR /app
COPY . .

RUN pip install --upgrade pip && pip install .

ENV PORT=8080
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:$PORT"]
