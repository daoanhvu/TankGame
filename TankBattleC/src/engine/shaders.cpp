
#include <iostream>
#include <fstream>
#include <sstream>

#include "shaders.h"
#include <glm/gtc/type_ptr.hpp>
#include <GLFW/glfw3.h>


std::string readShaderFile(const char* filePath) {
  std::string shaderCode;
  std::ifstream shaderFile;
  
  // Ensure ifstream objects can throw exceptions
  shaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
    
  try {
    // Open file
    shaderFile.open(filePath);
    std::stringstream shaderStream;
    
    // Read file's buffer contents into stream
    shaderStream << shaderFile.rdbuf();
    
    // Close file handler
    shaderFile.close();
    
    // Convert stream into string
    shaderCode = shaderStream.str();
  }
  catch(std::ifstream::failure& e) {
    std::cerr << "ERROR::SHADER::FILE_NOT_SUCCESSFULLY_READ: " << e.what() << std::endl;
  }
  
  return shaderCode;
}

// Function to compile shader
GLuint Shader::compile(const char* vSource, const char* fSource, std::string* infoLog) {
  GLint statusCode;
  GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShader, 1, &vSource, nullptr);
  glCompileShader(vertexShader);
  glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &statusCode);

  if (!statusCode) {
    if (infoLog != nullptr) {
      glGetShaderInfoLog(vertexShader, 512, nullptr, infoLog->data());
    }
    return statusCode;
  }

  GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragmentShader, 1, &fSource, nullptr);
  glCompileShader(fragmentShader);
  glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &statusCode);

  if (!statusCode) {
    if (infoLog != nullptr) {
      glGetShaderInfoLog(fragmentShader, 512, nullptr, infoLog->data());
    }
    glDeleteShader(vertexShader);
    return statusCode;
  }

  programId = glCreateProgram();
  glAttachShader(programId, vertexShader);
  glAttachShader(programId, fragmentShader);
  glLinkProgram(programId);

  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);

  glGetProgramiv(programId, GL_LINK_STATUS, &statusCode);
  if (!statusCode) {
    if (infoLog != nullptr) {
      glGetShaderInfoLog(fragmentShader, 512, nullptr, infoLog->data());
    }
    return statusCode;
  }
  
  return 0;
}

void Shader::use() const {
  glUseProgram(programId);
}

void Shader::setMat4(const char* name, const glm::mat4& m) const {
  GLint loc = glGetUniformLocation(programId, name); 
  if (loc >= 0) 
    glUniformMatrix4fv(loc, 1, GL_FALSE, glm::value_ptr(m));
}

void Shader::setMat4(GLint location, const glm::mat4& m) const { 
  glUniformMatrix4fv(location, 1, GL_FALSE, glm::value_ptr(m));
}

void Shader::setVec4(const char* name, const glm::vec4& v) const {
  GLint loc = glGetUniformLocation(programId, name); 
  if (loc >= 0) 
    glUniform4fv(loc, 1, &v.x);
}

void Shader::setVec4(GLint location, const glm::vec4& v) const {
  glUniform4fv(location, 1, &v.x);
}