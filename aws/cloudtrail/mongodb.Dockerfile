FROM mongo
#RUN adduser --uid 500 ec2-user
RUN adduser --uid 1000 krogebry
#RUN chown -R ec2-user:ec2-user /data/*
RUN chown -R krogebry:krogebry /data/*
#USER ec2-user
USER krogebry
