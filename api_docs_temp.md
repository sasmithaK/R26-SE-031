### Auth & Student Service (C5)
#### `POST /api/v1/auth/signup`
- **Summary**: Signup
- **Request Body**:
  ```json
  {
  "name": {
    "type": "string",
    "maxLength": 50,
    "minLength": 2,
    "title": "Name"
  },
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  },
  "password": {
    "type": "string",
    "minLength": 8,
    "title": "Password",
    "description": "Password must be at least 8 characters long"
  },
  "role": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Role",
    "default": "parent"
  },
  "specialization": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Specialization"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  }
}
  ```
- **Response**: Successful Response

#### `DELETE /api/v1/auth/cancel-signup/{email}`
- **Summary**: Cancel Signup
- **Response**: Successful Response

#### `POST /api/v1/auth/verify-email`
- **Summary**: Verify Email
- **Request Body**:
  ```json
  {
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  },
  "otp": {
    "type": "string",
    "maxLength": 6,
    "minLength": 6,
    "title": "Otp"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "access_token": {
    "type": "string",
    "title": "Access Token"
  },
  "refresh_token": {
    "type": "string",
    "title": "Refresh Token"
  },
  "token_type": {
    "type": "string",
    "title": "Token Type",
    "default": "bearer"
  }
}
  ```

#### `POST /api/v1/auth/resend-otp`
- **Summary**: Resend Otp
- **Request Body**:
  ```json
  {
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  }
}
  ```
- **Response**: Successful Response

#### `POST /api/v1/auth/login`
- **Summary**: Login
- **Request Body**:
  ```json
  {
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  },
  "password": {
    "type": "string",
    "minLength": 8,
    "title": "Password"
  },
  "device_id": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Device Id"
  },
  "device_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Device Name"
  },
  "role": {
    "type": "string",
    "title": "Role"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "access_token": {
    "type": "string",
    "title": "Access Token"
  },
  "refresh_token": {
    "type": "string",
    "title": "Refresh Token"
  },
  "token_type": {
    "type": "string",
    "title": "Token Type",
    "default": "bearer"
  }
}
  ```

#### `POST /api/v1/auth/google`
- **Summary**: Google Login
- **Request Body**:
  ```json
  {
  "id_token": {
    "type": "string",
    "title": "Id Token"
  },
  "device_id": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Device Id"
  },
  "device_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Device Name"
  },
  "role": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Role",
    "default": "parent"
  },
  "specialization": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Specialization"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "access_token": {
    "type": "string",
    "title": "Access Token"
  },
  "refresh_token": {
    "type": "string",
    "title": "Refresh Token"
  },
  "token_type": {
    "type": "string",
    "title": "Token Type",
    "default": "bearer"
  }
}
  ```

#### `POST /api/v1/auth/microsoft`
- **Summary**: Microsoft Login
- **Request Body**:
  ```json
  {
  "access_token": {
    "type": "string",
    "title": "Access Token"
  },
  "device_id": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Device Id"
  },
  "device_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Device Name"
  },
  "role": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Role",
    "default": "parent"
  },
  "specialization": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Specialization"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "access_token": {
    "type": "string",
    "title": "Access Token"
  },
  "refresh_token": {
    "type": "string",
    "title": "Refresh Token"
  },
  "token_type": {
    "type": "string",
    "title": "Token Type",
    "default": "bearer"
  }
}
  ```

#### `POST /api/v1/auth/refresh`
- **Summary**: Refresh Token Endpoint
- **Request Body**:
  ```json
  {
  "refresh_token": {
    "type": "string",
    "title": "Refresh Token"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "access_token": {
    "type": "string",
    "title": "Access Token"
  },
  "refresh_token": {
    "type": "string",
    "title": "Refresh Token"
  },
  "token_type": {
    "type": "string",
    "title": "Token Type",
    "default": "bearer"
  }
}
  ```

#### `GET /api/v1/auth/me`
- **Summary**: Get Me
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "name": {
    "type": "string",
    "title": "Name"
  },
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  },
  "role": {
    "type": "string",
    "title": "Role"
  },
  "login_alerts_enabled": {
    "type": "boolean",
    "title": "Login Alerts Enabled",
    "default": true
  },
  "profile_picture_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Profile Picture Url"
  },
  "clinic_code": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Code"
  },
  "specialization": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Specialization"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  }
}
  ```

#### `PUT /api/v1/auth/me`
- **Summary**: Update Me
- **Request Body**:
  ```json
  {
  "name": {
    "anyOf": [
      {
        "type": "string",
        "maxLength": 50,
        "minLength": 2
      },
      {
        "type": "null"
      }
    ],
    "title": "Name"
  },
  "email": {
    "anyOf": [
      {
        "type": "string",
        "format": "email"
      },
      {
        "type": "null"
      }
    ],
    "title": "Email"
  },
  "specialization": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Specialization"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "name": {
    "type": "string",
    "title": "Name"
  },
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  },
  "role": {
    "type": "string",
    "title": "Role"
  },
  "login_alerts_enabled": {
    "type": "boolean",
    "title": "Login Alerts Enabled",
    "default": true
  },
  "profile_picture_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Profile Picture Url"
  },
  "clinic_code": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Code"
  },
  "specialization": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Specialization"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  }
}
  ```

#### `DELETE /api/v1/auth/me`
- **Summary**: Delete My Account

#### `POST /api/v1/auth/request-email-update`
- **Summary**: Request Email Update
- **Request Body**:
  ```json
  {
  "new_email": {
    "type": "string",
    "format": "email",
    "title": "New Email"
  }
}
  ```
- **Response**: Successful Response

#### `POST /api/v1/auth/verify-email-update`
- **Summary**: Verify Email Update
- **Request Body**:
  ```json
  {
  "new_email": {
    "type": "string",
    "format": "email",
    "title": "New Email"
  },
  "otp": {
    "type": "string",
    "maxLength": 6,
    "minLength": 6,
    "title": "Otp"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "access_token": {
    "type": "string",
    "title": "Access Token"
  },
  "refresh_token": {
    "type": "string",
    "title": "Refresh Token"
  },
  "token_type": {
    "type": "string",
    "title": "Token Type",
    "default": "bearer"
  }
}
  ```

#### `POST /api/v1/auth/change-password`
- **Summary**: Change Password
- **Request Body**:
  ```json
  {
  "old_password": {
    "type": "string",
    "title": "Old Password"
  },
  "new_password": {
    "type": "string",
    "minLength": 8,
    "title": "New Password"
  }
}
  ```
- **Response**: Successful Response

#### `POST /api/v1/auth/verify-password`
- **Summary**: Verify User Password
- **Request Body**:
  ```json
  {
  "password": {
    "type": "string",
    "title": "Password"
  }
}
  ```
- **Response**: Successful Response

#### `POST /api/v1/auth/forgot-password`
- **Summary**: Forgot Password
- **Request Body**:
  ```json
  {
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  }
}
  ```
- **Response**: Successful Response

#### `POST /api/v1/auth/reset-password`
- **Summary**: Reset Password
- **Request Body**:
  ```json
  {
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  },
  "otp": {
    "type": "string",
    "maxLength": 6,
    "minLength": 6,
    "title": "Otp"
  },
  "new_password": {
    "type": "string",
    "minLength": 8,
    "title": "New Password"
  }
}
  ```
- **Response**: Successful Response

#### `PUT /api/v1/auth/settings/login-alerts`
- **Summary**: Toggle Login Alerts
- **Request Body**:
  ```json
  {
  "enabled": {
    "type": "boolean",
    "title": "Enabled"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "name": {
    "type": "string",
    "title": "Name"
  },
  "email": {
    "type": "string",
    "format": "email",
    "title": "Email"
  },
  "role": {
    "type": "string",
    "title": "Role"
  },
  "login_alerts_enabled": {
    "type": "boolean",
    "title": "Login Alerts Enabled",
    "default": true
  },
  "profile_picture_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Profile Picture Url"
  },
  "clinic_code": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Code"
  },
  "specialization": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Specialization"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  }
}
  ```

#### `POST /api/v1/auth/profile/picture`
- **Summary**: Upload Profile Picture
- **Request Body**:
  ```json
  {}
  ```
- **Response**: Successful Response

#### `DELETE /api/v1/auth/profile/picture`
- **Summary**: Delete Profile Picture
- **Response**: Successful Response

#### `GET /api/v1/auth/profile/picture/{file_id}`
- **Summary**: Get Profile Picture
- **Response**: Successful Response

#### `GET /api/v1/auth/students`
- **Summary**: List Students
- **Response**: Successful Response
  ```json
  {
  "items": {
    "$ref": "#/components/schemas/StudentResponse"
  },
  "type": "array",
  "title": "Response List Students Api V1 Auth Students Get"
}
  ```

#### `POST /api/v1/auth/students`
- **Summary**: Add Student
- **Request Body**:
  ```json
  {
  "first_name": {
    "type": "string",
    "maxLength": 50,
    "minLength": 1,
    "title": "First Name"
  },
  "last_name": {
    "type": "string",
    "maxLength": 50,
    "minLength": 1,
    "title": "Last Name"
  },
  "grade": {
    "type": "string",
    "title": "Grade",
    "default": "Grade 1"
  },
  "daily_limit": {
    "type": "string",
    "title": "Daily Limit",
    "default": "No Limit"
  },
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "title": "Assessment Results",
    "default": []
  },
  "comprehensive_assessment_results": {
    "additionalProperties": {
      "items": {
        "type": "boolean"
      },
      "type": "array"
    },
    "type": "object",
    "title": "Comprehensive Assessment Results",
    "default": {}
  },
  "completed_activities": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Completed Activities",
    "default": []
  },
  "activity_scores": {
    "additionalProperties": {
      "type": "integer"
    },
    "type": "object",
    "title": "Activity Scores",
    "default": {}
  },
  "avatar_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Avatar Url"
  },
  "consent_given": {
    "type": "boolean",
    "title": "Consent Given",
    "default": false
  },
  "consent_parent_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Consent Parent Name"
  },
  "consent_date": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Consent Date"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "first_name": {
    "type": "string",
    "title": "First Name"
  },
  "last_name": {
    "type": "string",
    "title": "Last Name"
  },
  "grade": {
    "type": "string",
    "title": "Grade"
  },
  "daily_limit": {
    "type": "string",
    "title": "Daily Limit"
  },
  "avatar_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Avatar Url"
  },
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "title": "Assessment Results",
    "default": []
  },
  "comprehensive_assessment_results": {
    "additionalProperties": {
      "items": {
        "type": "boolean"
      },
      "type": "array"
    },
    "type": "object",
    "title": "Comprehensive Assessment Results",
    "default": {}
  },
  "completed_activities": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Completed Activities",
    "default": []
  },
  "activity_scores": {
    "additionalProperties": {
      "type": "integer"
    },
    "type": "object",
    "title": "Activity Scores",
    "default": {}
  },
  "assessment_completed": {
    "type": "boolean",
    "title": "Assessment Completed",
    "default": false
  }
}
  ```

#### `PUT /api/v1/auth/students/{student_id}`
- **Summary**: Update Student
- **Request Body**:
  ```json
  {
  "first_name": {
    "type": "string",
    "maxLength": 50,
    "minLength": 1,
    "title": "First Name"
  },
  "last_name": {
    "type": "string",
    "maxLength": 50,
    "minLength": 1,
    "title": "Last Name"
  },
  "grade": {
    "type": "string",
    "title": "Grade",
    "default": "Grade 1"
  },
  "daily_limit": {
    "type": "string",
    "title": "Daily Limit",
    "default": "No Limit"
  },
  "avatar_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Avatar Url"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "first_name": {
    "type": "string",
    "title": "First Name"
  },
  "last_name": {
    "type": "string",
    "title": "Last Name"
  },
  "grade": {
    "type": "string",
    "title": "Grade"
  },
  "daily_limit": {
    "type": "string",
    "title": "Daily Limit"
  },
  "avatar_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Avatar Url"
  },
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "title": "Assessment Results",
    "default": []
  },
  "comprehensive_assessment_results": {
    "additionalProperties": {
      "items": {
        "type": "boolean"
      },
      "type": "array"
    },
    "type": "object",
    "title": "Comprehensive Assessment Results",
    "default": {}
  },
  "completed_activities": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Completed Activities",
    "default": []
  },
  "activity_scores": {
    "additionalProperties": {
      "type": "integer"
    },
    "type": "object",
    "title": "Activity Scores",
    "default": {}
  },
  "assessment_completed": {
    "type": "boolean",
    "title": "Assessment Completed",
    "default": false
  }
}
  ```

#### `DELETE /api/v1/auth/students/{student_id}`
- **Summary**: Delete Student

#### `PATCH /api/v1/auth/students/{student_id}/assessment`
- **Summary**: Submit Assessment
- **Request Body**:
  ```json
  {
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "maxItems": 14,
    "minItems": 14,
    "title": "Assessment Results"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "first_name": {
    "type": "string",
    "title": "First Name"
  },
  "last_name": {
    "type": "string",
    "title": "Last Name"
  },
  "grade": {
    "type": "string",
    "title": "Grade"
  },
  "daily_limit": {
    "type": "string",
    "title": "Daily Limit"
  },
  "avatar_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Avatar Url"
  },
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "title": "Assessment Results",
    "default": []
  },
  "comprehensive_assessment_results": {
    "additionalProperties": {
      "items": {
        "type": "boolean"
      },
      "type": "array"
    },
    "type": "object",
    "title": "Comprehensive Assessment Results",
    "default": {}
  },
  "completed_activities": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Completed Activities",
    "default": []
  },
  "activity_scores": {
    "additionalProperties": {
      "type": "integer"
    },
    "type": "object",
    "title": "Activity Scores",
    "default": {}
  },
  "assessment_completed": {
    "type": "boolean",
    "title": "Assessment Completed",
    "default": false
  }
}
  ```

#### `PATCH /api/v1/auth/students/{student_id}/progress`
- **Summary**: Sync Progress
- **Request Body**:
  ```json
  {
  "completed_activities": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Completed Activities"
  },
  "activity_scores": {
    "additionalProperties": {
      "type": "integer"
    },
    "type": "object",
    "title": "Activity Scores"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "first_name": {
    "type": "string",
    "title": "First Name"
  },
  "last_name": {
    "type": "string",
    "title": "Last Name"
  },
  "grade": {
    "type": "string",
    "title": "Grade"
  },
  "daily_limit": {
    "type": "string",
    "title": "Daily Limit"
  },
  "avatar_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Avatar Url"
  },
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "title": "Assessment Results",
    "default": []
  },
  "comprehensive_assessment_results": {
    "additionalProperties": {
      "items": {
        "type": "boolean"
      },
      "type": "array"
    },
    "type": "object",
    "title": "Comprehensive Assessment Results",
    "default": {}
  },
  "completed_activities": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Completed Activities",
    "default": []
  },
  "activity_scores": {
    "additionalProperties": {
      "type": "integer"
    },
    "type": "object",
    "title": "Activity Scores",
    "default": {}
  },
  "assessment_completed": {
    "type": "boolean",
    "title": "Assessment Completed",
    "default": false
  }
}
  ```

#### `PATCH /api/v1/auth/students/{student_id}/comprehensive-assessment/{category}`
- **Summary**: Submit Comprehensive Assessment
- **Request Body**:
  ```json
  {
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "title": "Assessment Results"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "first_name": {
    "type": "string",
    "title": "First Name"
  },
  "last_name": {
    "type": "string",
    "title": "Last Name"
  },
  "grade": {
    "type": "string",
    "title": "Grade"
  },
  "daily_limit": {
    "type": "string",
    "title": "Daily Limit"
  },
  "avatar_url": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Avatar Url"
  },
  "assessment_results": {
    "items": {
      "type": "boolean"
    },
    "type": "array",
    "title": "Assessment Results",
    "default": []
  },
  "comprehensive_assessment_results": {
    "additionalProperties": {
      "items": {
        "type": "boolean"
      },
      "type": "array"
    },
    "type": "object",
    "title": "Comprehensive Assessment Results",
    "default": {}
  },
  "completed_activities": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Completed Activities",
    "default": []
  },
  "activity_scores": {
    "additionalProperties": {
      "type": "integer"
    },
    "type": "object",
    "title": "Activity Scores",
    "default": {}
  },
  "assessment_completed": {
    "type": "boolean",
    "title": "Assessment Completed",
    "default": false
  }
}
  ```

#### `GET /api/v1/specialists/lookup/{clinic_code}`
- **Summary**: Lookup Specialist
- **Response**: Successful Response

#### `POST /api/v1/specialists/connect`
- **Summary**: Connect Specialist
- **Request Body**:
  ```json
  {
  "clinic_code": {
    "type": "string",
    "maxLength": 6,
    "minLength": 6,
    "title": "Clinic Code",
    "description": "6-digit code provided by the specialist"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "message": {
    "type": "string",
    "title": "Message"
  }
}
  ```

#### `GET /api/v1/specialists/students`
- **Summary**: Get Connected Students
- **Response**: Successful Response

#### `GET /api/v1/auth/activities/{skill_id}`
- **Summary**: Get Activities For Skill
- **Response**: Successful Response

#### `POST /api/v1/auth/therapist/generate-code`
- **Summary**: Generate Connection Code
- **Response**: Successful Response
  ```json
  {
  "clinic_code": {
    "type": "string",
    "title": "Clinic Code"
  },
  "expires_at": {
    "type": "string",
    "format": "date-time",
    "title": "Expires At"
  }
}
  ```

#### `POST /api/v1/auth/therapist/connect`
- **Summary**: Connect Specialist
- **Request Body**:
  ```json
  {
  "clinic_code": {
    "type": "string",
    "title": "Clinic Code"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  }
}
  ```
- **Response**: Successful Response
  ```json
  {
  "id": {
    "type": "string",
    "title": "Id"
  },
  "therapist_id": {
    "type": "string",
    "title": "Therapist Id"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "student_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Student Name"
  },
  "therapist_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Therapist Name"
  },
  "parent_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Parent Name"
  },
  "parent_email": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Parent Email"
  },
  "parent_profile_picture": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Parent Profile Picture"
  },
  "student_profile_picture": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Student Profile Picture"
  },
  "clinic_name": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "null"
      }
    ],
    "title": "Clinic Name"
  },
  "status": {
    "type": "string",
    "title": "Status",
    "default": "active"
  },
  "connected_at": {
    "type": "string",
    "format": "date-time",
    "title": "Connected At"
  }
}
  ```

#### `GET /api/v1/auth/therapist/connections`
- **Summary**: Get Connections
- **Response**: Successful Response
  ```json
  {
  "items": {
    "$ref": "#/components/schemas/TherapistConnectionResponse"
  },
  "type": "array",
  "title": "Response Get Connections Api V1 Auth Therapist Connections Get"
}
  ```

#### `DELETE /api/v1/auth/therapist/disconnect/{connection_id}`
- **Summary**: Disconnect Specialist
- **Response**: Successful Response

#### `GET /api/v1/parent/students/{student_id}/overview`
- **Summary**: Get Parent Overview
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "accuracy": {
    "type": "integer",
    "title": "Accuracy"
  },
  "practice_time_minutes": {
    "type": "integer",
    "title": "Practice Time Minutes"
  },
  "sessions_completed": {
    "type": "integer",
    "title": "Sessions Completed"
  },
  "reading_progress": {
    "type": "string",
    "title": "Reading Progress"
  }
}
  ```

#### `GET /api/v1/parent/students/{student_id}/fluency`
- **Summary**: Get Parent Fluency
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "fluency_status": {
    "type": "string",
    "title": "Fluency Status"
  },
  "fluency_score": {
    "type": "number",
    "title": "Fluency Score"
  }
}
  ```

#### `GET /api/v1/parent/students/{student_id}/progress`
- **Summary**: Get Parent Progress
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "accuracy_trend": {
    "items": {
      "additionalProperties": true,
      "type": "object"
    },
    "type": "array",
    "title": "Accuracy Trend"
  }
}
  ```

#### `GET /api/v1/parent/students/{student_id}/learning-pattern`
- **Summary**: Get Parent Learning Pattern
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "observation": {
    "type": "string",
    "title": "Observation"
  },
  "recommended_practices": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Recommended Practices"
  }
}
  ```

#### `GET /api/v1/parent/students/{student_id}/activity-history`
- **Summary**: Get Parent Activity History
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "history": {
    "items": {
      "$ref": "#/components/schemas/ActivityHistoryItem"
    },
    "type": "array",
    "title": "History"
  }
}
  ```

#### `GET /api/v1/parent/students/{student_id}/report`
- **Summary**: Download Parent Report
- **Response**: Successful Response

#### `GET /api/v1/therapist/students/{student_id}/overview`
- **Summary**: Get Therapist Overview
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "model_version": {
    "type": "string",
    "title": "Model Version"
  },
  "feature_version": {
    "type": "string",
    "title": "Feature Version"
  },
  "confidence": {
    "anyOf": [
      {
        "type": "number"
      },
      {
        "type": "null"
      }
    ],
    "title": "Confidence"
  },
  "accuracy": {
    "type": "number",
    "title": "Accuracy"
  },
  "attempted_items": {
    "type": "integer",
    "title": "Attempted Items"
  },
  "completed_sessions": {
    "type": "integer",
    "title": "Completed Sessions"
  },
  "reading_fluency_status": {
    "type": "string",
    "title": "Reading Fluency Status"
  },
  "overall_mastery": {
    "type": "number",
    "title": "Overall Mastery"
  },
  "current_pattern": {
    "type": "string",
    "title": "Current Pattern"
  },
  "pattern_confidence": {
    "type": "number",
    "title": "Pattern Confidence"
  },
  "fatigue_status": {
    "type": "string",
    "title": "Fatigue Status"
  },
  "last_active": {
    "type": "string",
    "title": "Last Active"
  }
}
  ```

#### `GET /api/v1/therapist/students/{student_id}/c1-behavioral`
- **Summary**: Get Therapist C1 Behavioral
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "model_version": {
    "type": "string",
    "title": "Model Version"
  },
  "feature_version": {
    "type": "string",
    "title": "Feature Version"
  },
  "confidence": {
    "anyOf": [
      {
        "type": "number"
      },
      {
        "type": "null"
      }
    ],
    "title": "Confidence"
  },
  "accuracy": {
    "type": "number",
    "title": "Accuracy"
  },
  "median_latency_ms": {
    "type": "number",
    "title": "Median Latency Ms"
  },
  "latency_variability": {
    "type": "number",
    "title": "Latency Variability"
  },
  "latency_drift": {
    "type": "number",
    "title": "Latency Drift"
  },
  "error_rate": {
    "type": "number",
    "title": "Error Rate"
  },
  "error_drift": {
    "type": "number",
    "title": "Error Drift"
  },
  "hesitation_rate": {
    "type": "number",
    "title": "Hesitation Rate"
  },
  "misclick_rate": {
    "type": "number",
    "title": "Misclick Rate"
  },
  "audio_replay_rate": {
    "type": "number",
    "title": "Audio Replay Rate"
  },
  "fatigue_score": {
    "type": "number",
    "title": "Fatigue Score"
  },
  "indices": {
    "$ref": "#/components/schemas/BehavioralIndices"
  },
  "trends": {
    "$ref": "#/components/schemas/BehavioralTrends"
  }
}
  ```

#### `GET /api/v1/therapist/students/{student_id}/c2-speech`
- **Summary**: Get Therapist C2 Speech
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "model_version": {
    "type": "string",
    "title": "Model Version"
  },
  "feature_version": {
    "type": "string",
    "title": "Feature Version"
  },
  "confidence": {
    "anyOf": [
      {
        "type": "number"
      },
      {
        "type": "null"
      }
    ],
    "title": "Confidence"
  },
  "latest": {
    "$ref": "#/components/schemas/SpeechLatest"
  },
  "trends": {
    "$ref": "#/components/schemas/SpeechTrends"
  }
}
  ```

#### `GET /api/v1/therapist/students/{student_id}/c3-profile`
- **Summary**: Get Therapist C3 Profile
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "model_version": {
    "type": "string",
    "title": "Model Version"
  },
  "feature_version": {
    "type": "string",
    "title": "Feature Version"
  },
  "confidence": {
    "type": "number",
    "title": "Confidence"
  },
  "primary_pattern": {
    "type": "string",
    "title": "Primary Pattern"
  },
  "probabilities": {
    "additionalProperties": {
      "type": "number"
    },
    "type": "object",
    "title": "Probabilities"
  },
  "modalities_used": {
    "items": {
      "type": "string"
    },
    "type": "array",
    "title": "Modalities Used"
  },
  "shap_explanations": {
    "items": {
      "$ref": "#/components/schemas/ShapExplanation"
    },
    "type": "array",
    "title": "Shap Explanations"
  }
}
  ```

#### `GET /api/v1/therapist/students/{student_id}/c4-adaptive`
- **Summary**: Get Therapist C4 Adaptive
- **Response**: Successful Response
  ```json
  {
  "updated_at": {
    "type": "string",
    "title": "Updated At"
  },
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "reporting_period": {
    "type": "string",
    "title": "Reporting Period"
  },
  "model_version": {
    "type": "string",
    "title": "Model Version"
  },
  "feature_version": {
    "type": "string",
    "title": "Feature Version"
  },
  "confidence": {
    "anyOf": [
      {
        "type": "number"
      },
      {
        "type": "null"
      }
    ],
    "title": "Confidence"
  },
  "knowledge_components": {
    "items": {
      "$ref": "#/components/schemas/KnowledgeComponent"
    },
    "type": "array",
    "title": "Knowledge Components"
  },
  "theta": {
    "type": "number",
    "title": "Theta"
  },
  "theta_se": {
    "type": "number",
    "title": "Theta Se"
  },
  "history": {
    "items": {
      "$ref": "#/components/schemas/AdaptiveHistoryItem"
    },
    "type": "array",
    "title": "History"
  }
}
  ```

#### `POST /api/v1/learning/interaction`
- **Summary**: Process Interaction
- **Request Body**:
  ```json
  {
  "student_id": {
    "type": "string",
    "title": "Student Id"
  },
  "session_id": {
    "type": "string",
    "title": "Session Id"
  },
  "activity_id": {
    "type": "string",
    "title": "Activity Id"
  },
  "item_id": {
    "type": "string",
    "title": "Item Id"
  },
  "knowledge_component_id": {
    "type": "string",
    "title": "Knowledge Component Id",
    "default": "KC_LETTER_IDENTITY"
  },
  "response": {
    "$ref": "#/components/schemas/InteractionResponseModel"
  },
  "telemetry": {
    "$ref": "#/components/schemas/TelemetryModel"
  },
  "speech": {
    "anyOf": [
      {},
      {
        "type": "null"
      }
    ],
    "title": "Speech"
  }
}
  ```
- **Response**: Successful Response

#### `GET /health`
- **Summary**: Health
- **Response**: Successful Response

Error loading Speech Monitoring Service (C2): No module named 'routers.stt'
Error loading Diagnostic Fusion Service (C3): cannot import name 'FusionRequest' from 'schemas' (D:\01 ACADEMIA\4th Year\Y4.S2\RP-IT4010\00 - Implementation\R26-SE-031\app\backend\api\schemas\__init__.py)
Error loading Adaptive Tutoring Service (C4): cannot import name 'InteractionRequest' from 'schemas' (D:\01 ACADEMIA\4th Year\Y4.S2\RP-IT4010\00 - Implementation\R26-SE-031\app\backend\api\schemas\__init__.py)
Error loading Telemetry Analytics Service (C1): No module named 'routers.telemetry'