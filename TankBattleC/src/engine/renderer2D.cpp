#include "renderer2D.h"
#include "texture2D.h"
#include <GLAD/gl.h>
#include <glm/gtc/matrix_transform.hpp>

static const char* kVS = R"GLSL(
  #version 330 core
  layout(location=0) in vec2 aPos;
  layout(location=1) in vec2 aUV;
  uniform mat4 uMVP;
  out vec2 vUV;
  void main() {
    vUV = aUV;
    gl_Position = uMVP * vec4(aPos, 0.0, 1.0);
  }
)GLSL";

static const char* kFS_color = R"GLSL(
  #version 330 core
  in vec2 vUV; // unused
  uniform vec4 uColor;
  out vec4 FragColor;
  void main() {
    FragColor = uColor;
  }
)GLSL";

static const char* kFS_tex = R"GLSL(
#version 330 core
in vec2 vUV;
uniform sampler2D uTex;
out vec4 FragColor;
void main(){ FragColor = texture(uTex, vUV); }
)GLSL";

void Renderer2D::init() {
  float verts[] = {
    // pos // uv
    -0.5f,-0.5f, 0.0f,0.0f,
    0.5f,-0.5f, 1.0f,0.0f,
    0.5f, 0.5f, 1.0f,1.0f,
    -0.5f, 0.5f, 0.0f,1.0f
  };
  unsigned idx[] = { 0,1,2, 2,3,0 };
  glGenVertexArrays(1, &vao); 
  glBindVertexArray(vao);
  glGenBuffers(1, &vbo); 
  glBindBuffer(GL_ARRAY_BUFFER,vbo);
  glBufferData(GL_ARRAY_BUFFER,sizeof(verts), verts, GL_STATIC_DRAW);
  glGenBuffers(1, &ebo); 
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo); 
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(idx), idx, GL_STATIC_DRAW);


  glEnableVertexAttribArray(0); 
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)0);
  glEnableVertexAttribArray(1); 
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)(2*sizeof(float)));


  std::string log;
  if(!shaderColor.compile(kVS, kFS_color, &log)){
    fprintf(stderr, "Shader color error: %s\n", log.c_str());
  }
  
  if(!shaderTex.compile(kVS, kFS_tex, &log)){
    fprintf(stderr, "Shader texture error: %s\n", log.c_str());
  }
}

void Renderer2D::begin(const glm::mat4& vp) {
  mVP = vp;
}

void Renderer2D::end() {
  // no-op now
}

void Renderer2D::drawQuad(const glm::vec2& pos, const glm::vec2& size, float rot, const glm::vec4& color) {
  glm::mat4 M(1.0f);
  M = glm::translate(M, glm::vec3(pos, 0.0f));
  M = glm::rotate(M, rot, glm::vec3(0, 0, 1));
  M = glm::scale(M, glm::vec3(size, 1.0f));

  glm::mat4 MVP = mVP * M;

  shaderColor.use();
  shaderColor.setMat4("uMVP", MVP);
  shaderColor.setVec4("uColor", color);

  glBindVertexArray(vao);
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}

void Renderer2D::drawQuadTex(const glm::vec2& pos, const glm::vec2& size, float rot, const Texture2D& tex) {
  glm::mat4 M(1.0f); 
  M = glm::translate(M, glm::vec3(pos,0.0f)); 
  M = glm::rotate(M, rot, glm::vec3(0,0,1)); 
  M = glm::scale(M, glm::vec3(size,1.0f));
  glm::mat4 MVP = mVP * M;
  shaderTex.use();
  shaderTex.setMat4("uMVP", MVP);
  glBindVertexArray(vao);
  tex.bind(0);
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}