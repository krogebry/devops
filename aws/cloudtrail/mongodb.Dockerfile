FROM mongo
RUN adduser --uid 500 ec2-user
USER ec2-user
