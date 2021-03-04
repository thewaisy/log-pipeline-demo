#!/bin/bash


curl -X POST -H "Content-Type: application/json" -H "id: test" -d \
"{ \
    \"event\" : \"page_view\", \
    \"data\": { \
      \"type\" : \"page\", \
      \"page_name\" : \"test_page\" \
    } \
  } \
"\
 http://localhost/


