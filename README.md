# Dynamic-Alexa-Skill-Using-Ruby-On-Lambda
This is a dynamic Alexa skill using ruby on lambda.

## Skill Setup
(This part expects you to have written a skill before. When I have time I will update with full instructions.)
- Setup a new Alexa Skill, Ruby Lambda, and connect them.
- In the lambda change the `rss_url` inside `SiteRssParser` class to the feed you want.
- Update `@application_id_check` inside the `lambda_handler` with your skill id.
- Add your intents
-- If you create a `next` intent in the Alexa developer portal, you need to create an `on_next` method in your lambda.
- End this on_ method with a `response.` 
-- In this lambda I only used seapk_text, so I not sure if the other methods currently work.
-- `response.speak_text("see ya!")` will have Alexa say "see ya!" and end the skill.
-- `response.speak_text("keep going?", false)` will have Alexa say "keep going?" and keep the skill open.
-- `response.speak_text("see ya!", false, {'step': 5})` will have Alexa respond the same as the previous and add 'step': 5 to the session attibute 
--- You can retrive this attribute by useing `@session_attributes['step']`

### This is adapted code, check out the original by Ryan Cunningham at https://github.com/rcunning/lambda.rb.
There is a beautiful hello-world-alexa example which will show you how to chain response methods.

### Tweaks/Updates
- Condensed it into one file and updated the lambda handler.
- Updated the Amazon intents. There are a few necessary intents and now those are included with simple phrases.
- Gave 'speak_text' method 2 optional parameters. First is end session and second is session attribute object. These will be explained in use section.
- Edited class variables
- Added and RSS Parser

### Big Thanks
This wouldn't have been possible without Ryan's code!
