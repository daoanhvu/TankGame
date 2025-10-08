#include "camera2D.h"
#include <glm/gtc/matrix_transform.hpp>

static glm::vec2 gTarget{0.0f};

void Camera2D::setViewport(float w, float h) {
  width=w; 
  height=h; 
  float halfW = width/(2.0f*pixelsPerUnit); 
  float halfH = height/(2.0f*pixelsPerUnit); 
  proj = glm::ortho(-halfW, halfW, -halfH, halfH, -1.0f, 1.0f);
}

void Camera2D::setZoom(float ppu) {
  pixelsPerUnit = ppu;
  setViewport(width, height);
}

void Camera2D::target(const glm::vec2& p) {
  gTarget = p;
}

void Camera2D::update(float dt) {
  glm::vec2 delta = gTarget - pos; 
  pos += delta * glm::clamp(dt*8.0f, 0.0f, 1.0f);
}

glm::mat4 Camera2D::viewProj() const {
  glm::mat4 V = glm::translate(glm::mat4(1.0f), glm::vec3(-pos, 0.0f));
  return proj * V;
}