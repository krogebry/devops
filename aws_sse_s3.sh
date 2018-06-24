#!/bin/bash
$(/opt/wt/bin/get_s3_env)
/opt/wt/bin/wt-api $@
