#ifndef _RENDERER_2D_H_
#define _RENDERER_2D_H_

#include "shaders.h"
#include <glm/glm.hpp>

class Texture2D;

class Renderer2D {
  private:
    unsigned int vao;
    unsigned int vbo;
    unsigned int ebo;
    glm::mat4 mVP{1.0f};
    Shader shaderColor;
    Shader shaderTex;

  public:
    void init();
    void begin(const glm::mat4& vp);
    void end();
    void drawQuad(const glm::vec2& pos, const glm::vec2& size, float rot, const glm::vec4& color);
    void drawQuadTex(const glm::vec2& pos, const glm::vec2& size, float rot, const Texture2D& tex);
};

#endif