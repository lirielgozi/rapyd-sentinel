#!/usr/bin/env python3
import json
import subprocess
import os

def lambda_handler(event, context):
    """
    Minimal Lambda handler that calls deploy.sh with appropriate parameters.
    """
    
    # Parse event
    action = event.get('action', 'deploy')
    target = event.get('target', 'both')
    image_tag = event.get('image_tag', 'latest')
    
    # Make deploy.sh executable
    subprocess.run(['chmod', '+x', '/var/task/deploy.sh'], check=False)
    
    try:
        # Call deploy.sh with parameters
        result = subprocess.run(
            ['/var/task/deploy.sh', action, target, image_tag],
            capture_output=True,
            text=True,
            timeout=300,
            env=os.environ.copy()
        )
        
        # Parse output based on action
        if action == 'status' and result.returncode == 0:
            # Try to parse JSON output for status
            try:
                output = json.loads(result.stdout)
            except:
                output = result.stdout
        else:
            output = result.stdout
        
        return {
            'statusCode': 200 if result.returncode == 0 else 500,
            'body': json.dumps({
                'success': result.returncode == 0,
                'output': output,
                'error': result.stderr if result.returncode != 0 else None
            })
        }
        
    except subprocess.TimeoutExpired:
        return {
            'statusCode': 504,
            'body': json.dumps({
                'success': False,
                'error': 'Script execution timed out after 300 seconds'
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }