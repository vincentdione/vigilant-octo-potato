#!/bin/bash



#!/bin/bash

# Variables
SONAR_PROJECT_KEY="my_quarkus_app"
SONAR_PROJECT_NAME="My Quarkus App"
SONAR_SOURCES="src/main/java"
SONAR_TARGET="target/classes"
SONAR_HOST_URL="http://sonarqube:9000"
SONAR_ADMIN_LOGIN="admin"
SONAR_ADMIN_PASSWORD="admin"
SONAR_USER="admin"
SONAR_USER_PASSWORD="sonar"
SONAR_TOKEN_NAME="squ_d6575dca0739fb958bbb431e3525c7be63b97205"
NETWORK="stack-local_sonar-network"



# Step 2: Start Docker Compose services
echo "Starting Docker Compose services..."
docker compose up -d

# Step 1: Start SonarQube container
#docker run -d --name sonarqube -p 9000:9000 sonarqube:latest

# Function to check if SonarQube is up
function wait_for_sonarqube() {
    echo "Waiting for SonarQube to start..."
    while ! curl --output /dev/null --silent --head --fail $SONAR_HOST_URL; do
        printf '.'
        sleep 5
    done
    echo "SonarQube is up and running."
}

# Call the function to wait for SonarQube
#wait_for_sonarqube

# Additional wait to ensure SonarQube is fully operational
echo "Giving SonarQube additional time to be fully operational..."
sleep 60

# Step 2: Create a user and generate a token
#echo "Creating a user and generating a token..."

# Login as admin and create a new user
#docker exec sonarqube curl -u $SONAR_ADMIN_LOGIN:$SONAR_ADMIN_PASSWORD -X POST -d "login=$SONAR_USER&name=$SONAR_USER&password=$SONAR_USER_PASSWORD" "$SONAR_HOST_URL/api/users/create"

# Generate a token for the new user
#SONAR_USER_TOKEN=$(docker exec sonarqube curl -u $SONAR_ADMIN_LOGIN:$SONAR_ADMIN_PASSWORD -X POST -d "name=$SONAR_TOKEN_NAME" "$SONAR_HOST_URL/api/user_tokens/generate" | grep -oP '(?<="token":")[^"]*')

#echo "Generated token: $SONAR_USER_TOKEN"

# Step 3: Run SonarQube analysis
echo "Running SonarQube analysis..."
echo ls -l 
echo pwd
docker run --rm \
  --network $NETWORK  \
  -v $(pwd):/usr/src/app \
  -w /usr/src/app \
  sonarsource/sonar-scanner-cli \
  sonar-scanner \
    -Dsonar.projectKey=$SONAR_PROJECT_KEY \
    -Dsonar.projectName="$SONAR_PROJECT_NAME" \
    -Dsonar.sources=$SONAR_SOURCES \
    -Dsonar.host.url=$SONAR_HOST_URL
    -Dsonar.java.binaries=$SONAR_TARGET
    -Dsonar.login=$SONAR_USER_TOKEN



