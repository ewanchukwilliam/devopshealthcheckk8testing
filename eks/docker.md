  # 1. Get your AWS account ID
  aws sts get-caller-identity --query Account --output text

  # 2. Create ECR repository
  aws ecr create-repository --repository-name health-service --region us-east-1

  # 3. Login to ECR
  aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

  # 4. Tag your image
  docker tag health-service:local \
    YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/health-service:latest

  # 5. Push to ECR
  docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/health-service:latest

  Then update eks/deployment.yaml:
  image: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/health-service:latest
  imagePullPolicy: Always  # Change from Never

