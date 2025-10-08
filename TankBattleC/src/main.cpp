// main.cpp
#include "engine/engine.h"
#include "engine/renderer2D.h"
#include "engine/input.h"
#include "engine/camera2D.h"
#include "engine/tilemap.h"
#include "engine/collision.h"
#include "engine/tank.h"
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

int main(int argc, char** args) {
  EngineConfiguration config; 
  config.windowTitle = "Tank — M2 Tilemap+AABB"; 
  config.width = 1280; 
  config.height = 720; 
  // config.clearColor = {0.07f, 0.08f, 0.10f, 1.0f};
  Engine appEngine;

  if (!appEngine.initialize(config)) {
    return -1;
  }

  Renderer2D renderer; 
  renderer.init();
  Camera2D camera; 
  camera.setViewport((float)config.width, (float)config.height); 
  camera.setZoom(100.0f);


  Tilemap map;
  map.loadMapFromFile("D:\\projects\\TankGame\\TankBattleC\\assets\\map1.txt");
  Tank tank; 
  tank.position = { map.tileSize*2.0f, map.tileSize*2.0f };

  while (appEngine.beginFrame()) {
    float dt = appEngine.deltaTime();

    // Input
    glm::vec2 dir{0.0f};
    if(Input::IsKeyDown(GLFW_KEY_W)) dir.y += 1.0f;
    if(Input::IsKeyDown(GLFW_KEY_S)) dir.y -= 1.0f;
    if(Input::IsKeyDown(GLFW_KEY_A)) dir.x -= 1.0f;
    if(Input::IsKeyDown(GLFW_KEY_D)) dir.x += 1.0f;
    if(glm::length(dir) > 0.0f) dir = glm::normalize(dir);


    if(Input::IsKeyDown(GLFW_KEY_Q)) tank.rot += tank.rotSpeed * dt;
    if(Input::IsKeyDown(GLFW_KEY_E)) tank.rot -= tank.rotSpeed * dt;

    // Desired move in local space
    glm::vec2 forward = { std::sin(tank.rot), std::cos(tank.rot) };
    glm::vec2 right = { forward.y, -forward.x };
    glm::vec2 desiredDelta = (forward*dir.y + right*dir.x) * (tank.speed * dt);

    // Collide against tiles
    CollisionResult cr = moveAndCollideAABB(map, tank.position, tank.half, desiredDelta);
    tank.position = cr.pos;

    camera.target(tank.position); 
    camera.update(dt);

    // Draw
    map.draw(renderer, camera.viewProj());
    renderer.begin(camera.viewProj());
    renderer.drawQuad(tank.position, {50, 70}, tank.rot, {0.1f, 0.8f, 0.2f, 1.0f});
    glm::vec2 turretPos = tank.position + glm::vec2(std::sin(tank.rot), std::cos(tank.rot))*25.0f;
    renderer.drawQuad(turretPos, {14, 30}, tank.rot, {0.05f, 0.5f, 0.1f, 1.0f});
    renderer.end(); 

    appEngine.endFrame();
  }

  return 0;
}