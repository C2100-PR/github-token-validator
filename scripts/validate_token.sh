#!/bin/bash

# Enhanced GitHub Token Validation Script
# Usage: ./validate_token.sh <github_token> [organization] [repository]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Check required argument
if [ -z "$1" ]; then
    echo -e "${RED}Error: GitHub token is required${NC}"
    echo "Usage: $0 <github_token> [organization] [repository]"
    exit 1
fi

TOKEN=$1
ORG=$2
REPO=$3

# Function to make API calls and handle errors
make_request() {
    local endpoint=$1
    local description=$2
    local expected_status=$3
    
    echo -e "\n${YELLOW}Testing: ${description}${NC}"
    
    response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $TOKEN" "https://api.github.com$endpoint")
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    case $status_code in
        200)
            echo -e "${GREEN}✓ Success${NC}"
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
            return 0
            ;;
        401)
            echo -e "${RED}✗ Authentication failed (401)${NC}"
            echo "- Check if token is valid and not expired"
            echo "- Verify token format is correct"
            echo "Response: $body"
            return 1
            ;;
        403)
            echo -e "${RED}✗ Forbidden (403)${NC}"
            echo "- Check if token has required permissions"
            echo "- Verify rate limits"
            echo "- Check organization access"
            echo "Response: $body"
            return 1
            ;;
        404)
            echo -e "${RED}✗ Not Found (404)${NC}"
            echo "- Verify repository exists and is accessible"
            echo "- Check organization membership"
            echo "- Confirm endpoint URL is correct"
            echo "Response: $body"
            return 1
            ;;
        *)
            echo -e "${RED}✗ Unexpected status code: $status_code${NC}"
            echo "Response: $body"
            return 1
            ;;
    esac
}

# Function to check rate limits with detailed output
check_rate_limits() {
    echo -e "\n${YELLOW}Checking API Rate Limits${NC}"
    local response=$(curl -s -H "Authorization: token $TOKEN" https://api.github.com/rate_limit)
    
    echo "Rate Limits:"
    echo "$response" | jq -r '"Core: \(.resources.core.remaining)/\(.resources.core.limit)"'
    echo "$response" | jq -r '"Search: \(.resources.search.remaining)/\(.resources.search.limit)"'
    echo "$response" | jq -r '"GraphQL: \(.resources.graphql.remaining)/\(.resources.graphql.limit)"'
}

# Function to check token scopes
check_scopes() {
    echo -e "\n${YELLOW}Checking Token Scopes${NC}"
    scopes=$(curl -s -I -H "Authorization: token $TOKEN" https://api.github.com | grep -i "x-oauth-scopes:" || echo "No scopes found")
    
    if [[ $scopes == *"repo"* ]]; then
        echo -e "${GREEN}✓ Has repo scope${NC}"
    else
        echo -e "${RED}✗ Missing repo scope${NC}"
    fi
    
    if [[ $scopes == *"workflow"* ]]; then
        echo -e "${GREEN}✓ Has workflow scope${NC}"
    else
        echo -e "${YELLOW}⚠ No workflow scope (only needed for Actions)${NC}"
    fi
    
    if [[ $scopes == *"read:org"* ]]; then
        echo -e "${GREEN}✓ Has read:org scope${NC}"
    else
        echo -e "${YELLOW}⚠ No read:org scope (only needed for org access)${NC}"
    fi
}

# Main validation sequence
echo "🔍 Starting GitHub Token Validation..."

# 1. Basic API access
make_request "" "Basic API Access"

# 2. Check token scopes
check_scopes

# 3. Organization access (if specified)
if [ ! -z "$ORG" ]; then
    make_request "/orgs/$ORG" "Organization Access"
fi

# 4. Repository access (if specified)
if [ ! -z "$ORG" ] && [ ! -z "$REPO" ]; then
    make_request "/repos/$ORG/$REPO" "Repository Access"
    make_request "/repos/$ORG/$REPO/actions/workflows" "Workflow Access"
fi

# 5. Check rate limits
check_rate_limits

# Final status
echo -e "\n${GREEN}Token validation complete!${NC}"