'use strict';

if (!ObjC.available) {
  console.log('[kayoko-overlay-safearea] Objective-C runtime is unavailable');
} else {
const tag = '[kayoko-overlay-safearea]';

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

function sceneOrientation(scene) {
  try {
    if (typeof scene.interfaceOrientation === 'function') {
      return orientationName(scene.interfaceOrientation());
    }
  } catch (error) {
  }
  return 'unavailable';
}

function dumpVisibleWindowSafeAreas(scene) {
  if (!scene || typeof scene.windows !== 'function') {
    return;
  }
  enumerateArray(scene.windows(), function (window, index) {
    try {
      if (window.isHidden()) {
        return;
      }
      log('sceneWindow#' + index + ' ' + objectSummary(window) +
        ' frame=' + rectString(window.frame()) +
        ' bounds=' + rectString(window.bounds()) +
        ' safeArea=' + insetsString(window.safeAreaInsets()) +
        ' level=' + Number(window.windowLevel()).toFixed(1));
    } catch (error) {
      log('sceneWindow#' + index + ' dump failed: ' + error.message);
    }
  });
}

function createOverlayAndDump() {
  const scene = firstWindowScene();
  if (!scene) {
    log('no UIWindowScene found');
    return;
  }

  const bounds = ObjC.classes.UIScreen.mainScreen().bounds();
  log('frontMost=' + frontMostOrientation() +
    ' screenBounds=' + rectString(bounds) +
    ' scene=' + objectSummary(scene) +
    ' sceneOrientation=' + sceneOrientation(scene));
  dumpVisibleWindowSafeAreas(scene);

  const root = ObjC.classes.UIViewController.alloc().init();
  const window = ObjC.classes.UIWindow.alloc().initWithWindowScene_(scene);
  window.setFrame_(bounds);
  window.setWindowLevel_(998.75);
  window.setBackgroundColor_(ObjC.classes.UIColor.clearColor());
  window.setRootViewController_(root);
  root.view().setBackgroundColor_(ObjC.classes.UIColor.clearColor());
  root.view().setNeedsLayout();
  root.view().layoutIfNeeded();
  window.setHidden_(false);

  globalThis.kayokoOverlaySafeAreaProbeWindow = window;
  globalThis.kayokoOverlaySafeAreaProbeRoot = root;

  setTimeout(function () {
    ObjC.schedule(ObjC.mainQueue, function () {
      try {
        root.view().setNeedsLayout();
        root.view().layoutIfNeeded();
        log('overlay window=' + objectSummary(window) +
          ' key=' + (window.isKeyWindow() ? 'YES' : 'NO') +
          ' frame=' + rectString(window.frame()) +
          ' bounds=' + rectString(window.bounds()) +
          ' safeArea=' + insetsString(window.safeAreaInsets()));
        log('overlay rootView frame=' + rectString(root.view().frame()) +
          ' bounds=' + rectString(root.view().bounds()) +
          ' safeArea=' + insetsString(root.view().safeAreaInsets()) +
          ' supportedMask=' + root.supportedInterfaceOrientations());
      } catch (error) {
        log('overlay dump failed: ' + error.message);
      }

      window.setHidden_(true);
      window.setRootViewController_(NULL);
      globalThis.kayokoOverlaySafeAreaProbeWindow = null;
      globalThis.kayokoOverlaySafeAreaProbeRoot = null;
      log('removed temporary overlay window');
    });
  }, 300);
}

ObjC.schedule(ObjC.mainQueue, createOverlayAndDump);
}
