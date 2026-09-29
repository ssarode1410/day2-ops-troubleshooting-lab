import json

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    # Process each message from the SQS queue
    for record in event.get('Records', []):
        body = record.get('body')
        print(f"Processing order: {body}")
        
    return {
        'statusCode': 200,
        'body': json.dumps('Order processed successfully!')
    }