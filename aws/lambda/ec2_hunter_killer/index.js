var AWS = require('aws-sdk');
var ec2 = new AWS.EC2();

var stack_name = process.env.STACK_NAME;
var ts_now = Date.now()/1000;

var candidate_pool = [];

exports.handler = function(event, context, callback) {
	ec2.describeInstances( function(err, data) {
		// console.log(JSON.stringify(data, null, 2));
    data['Reservations'].forEach(function( r ){
      r['Instances'].forEach(function( i ){
        console.log(i['LaunchTime']);
        var d = Date.parse(i['LaunchTime']);
        console.log(d);
        var uptime = ts_now - (d/1000);
		    console.log('uptime: %s', uptime);
      });
    });
	});
}


