#!/bin/bash
aws dynamodb put-item \
    --table-name orders \
    --item '{
        "partitionKey": {"S": "P001#johndoe@example.com"},
        "sortKey": {"S": "Wireless Mouse"},
        "orderId": {"S": "123456"},
        "customerName": {"S": "John Doe"},
        "customerEmail": {"S": "johndoe@example.com"},
        "orderDate": {"S": "2025-01-01T12:00:00Z"},
        "items": {"L": [
            {
                "M": {
                    "productId": {"S": "P001"},
                    "productName": {"S": "Wireless Mouse"},
                    "quantity": {"N": "2"},
                    "price": {"N": "25.99"}
                }
            }
        ]}
    }'
