FROM public.ecr.aws/lambda/python:3.11

WORKDIR /var/task

COPY requirements.txt .
RUN pip install -r requirements.txt --no-cache-dir

COPY order_retrieval.py .

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/var/task
ENV DEBUG=true

USER nobody

HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/2018-06-01/runtime/healthcheck || exit 1

CMD [ "order_retrieval.lambda_handler" ]
