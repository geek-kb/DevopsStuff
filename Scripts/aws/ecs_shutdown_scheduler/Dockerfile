FROM public.ecr.aws/lambda/python:3.8
ENV LANG=en_US.UTF-8
ENV TZ=:/etc/localtime
ENV PATH=/var/lang/bin:/usr/local/bin:/usr/bin/:/bin:/opt/bin
ENV LD_LIBRARY_PATH=/var/lang/lib:/lib64:/usr/lib64:/var/runtime:/var/runtime/lib:/var/task:/var/task/lib:/opt/lib
ENV LAMBDA_TASK_ROOT=/var/task
ENV LAMBDA_RUNTIME_DIR=/var/runtime

COPY . $LAMBDA_TASK_ROOT
WORKDIR $LAMBDA_TASK_ROOT
RUN pip install -r requirements.txt
CMD ["schedule_containers.lambda_handler"]
