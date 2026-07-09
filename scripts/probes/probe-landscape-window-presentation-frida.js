'use strict';

if (!ObjC.available) {
  console.log('[kayoko-window-presentation] Objective-C runtime is unavailable');
} else {
const tag = '[kayoko-window-presentation]';

function log(message) {
  console.log(tag + ' ' + message);
}

function selector(name) {
  try {
    return ObjC.selector(name);
  } catch (error) {
    return ptr('0');
  }
}

function methodFunctionForObject(object, selectorName, returnType) {
  try {
    const method = object.$class['- ' + selectorName];
    if (!method) {
      return null;
    }
    return new NativeFunction(method.implementation, returnType, ['pointer', 'pointer']);
  } catch (error) {
    return null;
  }
}

function orientationName(value) {
  const orientation = Number(value);
  switch (orientation) {
    case 0:
      return 'unknown(0)';
    case 1:
      return 'portrait(1)';
    case 2:
      return 'portraitUpsideDown(2)';
    case 3:
      return 'landscapeRight(3)';
    case 4:
      return 'landscapeLeft(4)';
    default:
      return 'orientation(' + orientation + ')';
  }
}

function frontMostOrientation() {
  try {
    const application = ObjC.classes.UIApplication.sharedApplication();
    const fn = methodFunctionForObject(application, '_frontMostAppOrientation', 'long');
    if (fn) {
      return orientationName(fn(application.handle, selector('_frontMostAppOrientation')));
    }
  } catch (error) {
    return 'error:' + error.message;
  }
  return 'unavailable';
}

function rectString(rect) {
  try {
    const values = [Number(rect.origin.x), Number(rect.origin.y), Number(rect.size.width), Number(rect.size.height)];
    if (values.every(function (value) { return !Number.isNaN(value); })) {
      return '{{' + values[0].toFixed(1) + ',' + values[1].toFixed(1) + '},{' +
        values[2].toFixed(1) + ',' + values[3].toFixed(1) + '}}';
    }
  } catch (error) {
  }
  return String(rect);
}

function pointString(point) {
  try {
    return '{' + Number(point.x).toFixed(1) + ',' + Number(point.y).toFixed(1) + '}';
  } catch (error) {
    return String(point);
  }
}

function sizeString(size) {
  try {
    return '{' + Number(size.width).toFixed(1) + ',' + Number(size.height).toFixed(1) + '}';
  } catch (error) {
    return String(size);
  }
}

function insetsString(insets) {
  try {
    let values = [Number(insets.top), Number(insets.left), Number(insets.bottom), Number(insets.right)];
    if (!values.every(function (value) { return !Number.isNaN(value); })) {
      values = String(insets).split(',').map(function (part) {
        return Number(part.trim());
      });
    }
    if (values.length >= 4 && values.slice(0, 4).every(function (value) { return !Number.isNaN(value); })) {
      return '{top=' + values[0].toFixed(1) +
        ', left=' + values[1].toFixed(1) +
        ', bottom=' + values[2].toFixed(1) +
        ', right=' + values[3].toFixed(1) + '}';
    }
  } catch (error) {
  }
  return String(insets);
}

function transformString(transform) {
  try {
    return '{a=' + Number(transform.a).toFixed(3) +
      ', b=' + Number(transform.b).toFixed(3) +
      ', c=' + Number(transform.c).toFixed(3) +
      ', d=' + Number(transform.d).toFixed(3) +
      ', tx=' + Number(transform.tx).toFixed(1) +
      ', ty=' + Number(transform.ty).toFixed(1) + '}';
  } catch (error) {
    return String(transform);
  }
}

function objectSummary(object) {
  if (!object || object.handle.isNull()) {
    return 'nil';
  }
  return object.$className + '<' + object.handle + '>';
}

function enumerateArray(array, callback) {
  const count = Number(array.count());
  for (let index = 0; index < count; index++) {
    callback(array.objectAtIndex_(index), index);
  }
}

function enumerateSet(set, callback) {
  const enumerator = set.objectEnumerator();
  let index = 0;
  while (true) {
    const object = enumerator.nextObject();
    if (!object || object.handle.isNull()) {
      break;
    }
    callback(object, index);
    index++;
  }
}

function firstWindowScene() {
  const application = ObjC.classes.UIApplication.sharedApplication();
  let selectedScene = null;
  enumerateSet(application.connectedScenes(), function (scene) {
    if (selectedScene || typeof scene.windows !== 'function') {
      return;
    }
    selectedScene = scene;
  });
  return selectedScene;
}

function currentKeyWindow() {
  const scene = firstWindowScene();
  if (scene && typeof scene.windows === 'function') {
    let keyWindow = null;
    enumerateArray(scene.windows(), function (window) {
      if (!keyWindow && window.isKeyWindow()) {
        keyWindow = window;
      }
    });
    if (keyWindow) {
      return keyWindow;
    }
  }

  try {
    return ObjC.classes.UIApplication.sharedApplication().keyWindow();
  } catch (error) {
    return null;
  }
}

function dumpWindow(label, window, root) {
  let line = label + ' window=' + objectSummary(window);
  try {
    line += ' key=' + (window.isKeyWindow() ? 'YES' : 'NO');
    line += ' canBecomeKey=' + (window.canBecomeKeyWindow() ? 'YES' : 'NO');
    line += ' hidden=' + (window.isHidden() ? 'YES' : 'NO');
    line += ' frame=' + rectString(window.frame());
    line += ' bounds=' + rectString(window.bounds());
    line += ' center=' + pointString(window.center());
    line += ' transform=' + transformString(window.transform());
    line += ' safeArea=' + insetsString(window.safeAreaInsets());
    line += ' layerBounds=' + rectString(window.layer().bounds());
    line += ' layerPosition=' + pointString(window.layer().position());
  } catch (error) {
    line += ' dumpError=' + error.message;
  }
  log(line);

  try {
    log(label + ' rootView=' + objectSummary(root.view()) +
      ' frame=' + rectString(root.view().frame()) +
      ' bounds=' + rectString(root.view().bounds()) +
      ' safeArea=' + insetsString(root.view().safeAreaInsets()) +
      ' supportedMask=' + root.supportedInterfaceOrientations());
  } catch (error) {
    log(label + ' root dump failed: ' + error.message);
  }
}

function runVariant(variant, done) {
  const scene = firstWindowScene();
  if (!scene) {
    log('no UIWindowScene found');
    done();
    return;
  }

  const previousKeyWindow = currentKeyWindow();
  const bounds = ObjC.classes.UIScreen.mainScreen().bounds();
  const root = ObjC.classes.UIViewController.alloc().init();
  const window = ObjC.classes.UIWindow.alloc().initWithWindowScene_(scene);
  window.setFrame_(bounds);
  window.setWindowLevel_(998.75);
  window.setBackgroundColor_(ObjC.classes.UIColor.clearColor());
  window.setOpaque_(false);
  window.setClipsToBounds_(variant.clipsToBounds);
  window.setRootViewController_(root);
  root.view().setBackgroundColor_(ObjC.classes.UIColor.clearColor());

  globalThis.kayokoWindowPresentationProbeWindow = window;
  globalThis.kayokoWindowPresentationProbeRoot = root;

  log('variant=' + variant.name +
    ' frontMost=' + frontMostOrientation() +
    ' screenBounds=' + rectString(bounds) +
    ' previousKey=' + objectSummary(previousKeyWindow));

  if (variant.makeKeyAndVisible) {
    window.makeKeyAndVisible();
  } else {
    window.setHidden_(false);
  }

  if (variant.setFrameAfterVisible) {
    window.setFrame_(ObjC.classes.UIScreen.mainScreen().bounds());
  }

  root.view().setNeedsLayout();
  root.view().layoutIfNeeded();

  setTimeout(function () {
    ObjC.schedule(ObjC.mainQueue, function () {
      dumpWindow(variant.name, window, root);
      window.setHidden_(true);
      window.setRootViewController_(NULL);
      if (previousKeyWindow && !previousKeyWindow.handle.isNull() && typeof previousKeyWindow.makeKeyWindow === 'function') {
        previousKeyWindow.makeKeyWindow();
      }
      globalThis.kayokoWindowPresentationProbeWindow = null;
      globalThis.kayokoWindowPresentationProbeRoot = null;
      setTimeout(function () {
        ObjC.schedule(ObjC.mainQueue, done);
      }, 250);
    });
  }, 350);
}

ObjC.schedule(ObjC.mainQueue, function () {
  const variants = [
    { name: 'hiddenFalse_clipped', makeKeyAndVisible: false, setFrameAfterVisible: false, clipsToBounds: true },
    { name: 'hiddenFalse_setFrameAfter_clipped', makeKeyAndVisible: false, setFrameAfterVisible: true, clipsToBounds: true },
    { name: 'makeKeyAndVisible_clipped', makeKeyAndVisible: true, setFrameAfterVisible: false, clipsToBounds: true },
    { name: 'makeKeyAndVisible_setFrameAfter_clipped', makeKeyAndVisible: true, setFrameAfterVisible: true, clipsToBounds: true },
  ];

  let index = 0;
  function next() {
    if (index >= variants.length) {
      log('done');
      return;
    }
    const variant = variants[index++];
    runVariant(variant, next);
  }

  next();
});
}
