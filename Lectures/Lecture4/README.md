## Assignment №4: Monte-Carlo light evaluation.

1. Select a HDR cubemap (for example, from [this site](http://noemotionhdrs.net/hdrday.html))
2. Import it into Unity. Select `Default / Cube` as texture type with `Mirrored ball` mapping type 
3. Implement Monte-Carlo evaluation shader for a configurable BSDF/BRDF by normalizing a diffuse + specular ([Blinn-Phong](https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_reflection_model)) approach.
4. Send me a screenshot of your results at mischapanin@gmail.com along with your code and a few object set-ups (best as a link to a repository, but an archive will work).
5. The e-mail should have the following topic: __HSE.CG.<your_name>.<your_last_name>.HW4__

**Bonus points:** 
You can get an extra 10-20% bonus if you use a more sophisticated BSDF such as [Cook-Torrance](https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf).
Which is a de-facto standard in high-quality real-time graphics.

**Note:**
You don't have to make it fully realtime. Just make it somewhat interactive and keep the minimum noize from Monte-Carlo integration.
