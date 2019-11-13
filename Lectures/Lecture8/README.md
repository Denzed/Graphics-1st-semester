## Assignment №8: Clouds Rendering

1. Select any method for modelling cloud volume. I recommend a combination of a height gradients, a control(weather) texture, and a few noise textures. You can use [3d-party](https://github.com/mtwoodard/TextureGenerator) noise generators.
2. Either render clouds inside a [skybox shader](https://github.com/keijiro/UnitySkyboxShaders) or using a huge horizontal plane above the camera, or other method you see fit.
3. Implement raymarching + cone-traced Beer's law
4. Send me a screenshot of your results at mischapanin@gmail.com along with your code. **Please clearly state if you want the bonus points and what for.**
5. The e-mail should have the following topic: __HSE.CG.<your_name>.<your_last_name>.HW8__

**Bonus points:** 
+ 20% for weather control texture with per-pixel density, cloud type, rain 
+ 10% for animation of the clouds
+ 10% for Beer's-Powder law
+ 15% for efficient Skipping of the empty space.
+ up to 50% for any other clever tricks.
