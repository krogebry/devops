/**
  * Ripped off from AWS
  */
var aws  = require('aws-sdk'), // Loads the AWS SDK for JavaScript.
    config = new aws.ConfigService(), // Constructs a service object to use the aws.ConfigService class.
    COMPLIANCE_STATES = {
        COMPLIANT: 'COMPLIANT',
        NON_COMPLIANT: 'NON_COMPLIANT',
        NOT_APPLICABLE: 'NOT_APPLICABLE'
    };

// Receives the event and context from AWS Lambda.exports.handler = function(event, context, callback) {
exports.handler = function(event, context, callback) {
    // Parses the invokingEvent and ruleParameters values, which contain JSON objects passed as strings.
    var invokingEvent = JSON.parse(event.invokingEvent),
        ruleParameters = JSON.parse(event.ruleParameters),
        compliance = COMPLIANCE_STATES.NOT_APPLICABLE,
        putEvaluationsRequest;

    compliance = evaluateCompliance(invokingEvent.configurationItem, ruleParameters);

    // Initializes the request that contains the evaluation results.
    putEvaluationsRequest = {
        Evaluations: [{
          // Applies the evaluation result to the resource published in the event.
          ComplianceResourceType: invokingEvent.configurationItem.resourceType,
          ComplianceResourceId: invokingEvent.configurationItem.resourceId,
          ComplianceType: compliance,
          OrderingTimestamp: invokingEvent.configurationItem.configurationItemCaptureTime
        }],
        ResultToken: event.resultToken
    };

    // Sends the evaluation results to AWS Config.
    config.putEvaluations(putEvaluationsRequest, function (err, data) {
        if (err) {
            callback(err, null);
        } else {
            if(data.FailedEvaluations.length > 0) {
                // Ends the function execution if any evaluation results are not successfully reported.
                callback(null, JSON.stringify(data));
            } else {
                callback(null, data);
            }
        }
    });
};

// Evaluates the resource and returns the compliance value to the handler.
function evaluateCompliance(configurationItem, ruleParameters) {
  console.log(configurationItem.configuration.groupName);
  for( i=0; i < configurationItem.configuration.ipPermissions.length; i++) {
    var ip = configurationItem.configuration.ipPermissions[i];
    console.log(ip);

    if( ip.fromPort == ruleParameters.targetPort ) {
      console.log(ip.ipRanges);
      for( j=0; j < ip.ipRanges.length; j++ ) {
        ip_cidr = ip.ipRanges[j];
        console.log( ip_cidr );
        if( ip_cidr == "0.0.0.0/0" ) {
          return COMPLIANCE_STATES.NON_COMPLIANT;
        }
      }
    }

  }
  return COMPLIANCE_STATES.COMPLIANT;
}
