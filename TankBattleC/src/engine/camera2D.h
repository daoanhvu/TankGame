#ifndef _CAMERA_2D_H_
#define _CAMERA_2D_H_

#include <glm/glm.hpp>

class Camera2D {
  private:
    float width=1280;
    float height=720;
    float pixelsPerUnit = 100.0f; // zoom: more = zoom in
    glm::vec2 pos{0.0f};
    glm::mat4 proj{1.0f};

  public:
    void setViewport(float w, float h);
    void setZoom(float ppu); // pixels per world unit
    void target(const glm::vec2& p); // set desired target position
    void update(float dt);
    glm::mat4 viewProj() const;
};

#endif