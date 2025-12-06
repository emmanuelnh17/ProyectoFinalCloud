provider "aws" {
  region = "us-east-1"
}

# --- 1. Base de Datos (DynamoDB) ---
resource "aws_dynamodb_table" "pedidos_table" {
  name           = "PedidosCafe"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# --- 2. Rol IAM para Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "RoleServidorPedidos_Terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Permisos para DynamoDB y Logs
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "logs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- 3. Función Lambda ---
resource "aws_lambda_function" "procesar_pedido" {
  filename      = "lambda_function.zip" # Se asume que el código está comprimido aquí
  function_name = "ProcesarPedido"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.pedidos_table.name
    }
  }
}

# --- 4. API Gateway (HTTP API) ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "CafeAPI"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.procesar_pedido.invoke_arn
}

resource "aws_apigatewayv2_route" "post_pedido" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /pedido"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Permiso para que API Gateway invoque la Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.procesar_pedido.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# --- 5. Frontend (S3 Bucket) ---
resource "aws_s3_bucket" "frontend_bucket" {
  bucket_prefix = "proyecto-cafe-" # Terraform añadirá un ID único
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
    }]
  })
}
