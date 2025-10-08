#ifndef _SHADERS_H_
#define _SHADERS_H_

#include <string>
#include <glad/gl.h>
#include <glm/glm.hpp>

enum BUFFER_TYPE {
    ONE_BUFFER,
    POSITION_NORMAL_AND_COLOR
};

typedef struct tagLocation {
  GLuint positionLocation;
  GLuint normalLocation;
  GLuint colorLocation;
  GLuint textureLocation;
  
  //uniform variables
  GLuint mvpMatrixId;
  GLuint perspectiveMatrixId;
  GLuint viewMatrixId;
  GLuint viewPosId;
  GLuint modelMatrixId;
	GLuint modelViewMatrixId;
  GLuint normalMatrixId;
  GLuint useNormalID;
  GLuint useLightingLocation;
  GLuint pointSizeLocation;
  GLuint lightPos1ID;
  GLuint lightPos2ID;
  GLuint lightColor1ID;
  GLuint lightColor2ID;
} ShaderVarLocation;

std::string readShaderFile(const char* filePath);


class Shader {
  private:
    GLint programId;

  public:
    GLuint compile(const char* vSource, const char* fSource, std::string* infoLog);
    void use() const;
    void setMat4(const char* name, const glm::mat4& m) const;
    void setMat4(GLint location, const glm::mat4& m) const;
    void setVec4(const char* name, const glm::vec4& v) const;
    void setVec4(GLint location, const glm::vec4& v) const;
};

#endif