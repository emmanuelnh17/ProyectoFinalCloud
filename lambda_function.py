import json
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('PedidosCafe')

def lambda_handler(event, context):
    try:
        print("Evento recibido:", json.dumps(event))
        
        body = event.get('body')
        if isinstance(body, str):
            datos = json.loads(body)
        else:
            datos = body if body else {}

        producto = datos.get('producto')
        cliente = datos.get('cliente', 'Anónimo')
        
        if not producto:
            return {
                'statusCode': 400,
                'body': json.dumps('Error: Falta el producto')
            }

        pedido_id = str(uuid.uuid4()) 
        fecha = datetime.now().isoformat()
        
        item = {
            'id': pedido_id,
            'cliente': cliente,
            'producto': producto,
            'fecha': fecha,
            'estado': 'Recibido'
        }

        # 5. Guardar en DynamoDB
        table.put_item(Item=item)

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*', 
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps(f'Pedido de {producto} recibido con ID: {pedido_id}')
        }
        
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error interno: {str(e)}')
        }
