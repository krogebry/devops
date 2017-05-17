FROM mongo
RUN adduser --uid 500 ec2-user
RUN chown -R ec2-user:ec2-user /data/*
USER ec2-user
