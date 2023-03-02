var exec = require("cordova/exec");
var PLUGIN_NAME = "NotificarePush";


const EVENT_SUBSCRIPTIONS = [];
let EVENTS_NOT_SENT = [];

document.addEventListener('deviceready',
    function onDeviceReady() {
        exec(
        function onSuccess(event) {
            if(EVENT_SUBSCRIPTIONS.some((sub) => sub.event === event.name)){
                EVENT_SUBSCRIPTIONS.filter((sub) => sub.event === event.name).forEach((sub) => sub.callback(event.data));
            }else{
                EVENTS_NOT_SENT.push(event);
            }
        },
        function onFailure(error) {
            console.error('Failed to register event listener.', error);
        },
        'NotificarePush',
        'registerListener',
        []
        );
    },
    false
);

class EventSubscription {
  constructor(event, callback) {
    this.event = event;
    this.callback = callback;
    EVENT_SUBSCRIPTIONS.push(this);
    let EVENTS_SENT = [];
    EVENTS_NOT_SENT.forEach((subevent)=>{
      if(event === subevent.name){
        callback(subevent.data)
        EVENTS_SENT.push(subevent);
      }
    });

    EVENTS_NOT_SENT = EVENTS_NOT_SENT.filter((item)=>!EVENTS_SENT.some((item2)=> item === item2));
  }

  remove() {
    const index = EVENT_SUBSCRIPTIONS.indexOf(this);
    if (index >= 0) {
      EVENT_SUBSCRIPTIONS.splice(index, 1);
    }
  }
}

module.exports = class NotificarePush {
    static async setAuthorizationOptions(options){
        return new Promise((resolve, reject) => {
            exec(resolve, reject, PLUGIN_NAME, 'setAuthorizationOptions', [options]);
        });
    }

    static async setCategoryOptions(options){
        return new Promise((resolve, reject) => {
            exec(resolve, reject, PLUGIN_NAME, 'setCategoryOptions', [options]);
    });
  }

  static async setPresentationOptions(options){
    return new Promise((resolve, reject) => {
      exec(resolve, reject, PLUGIN_NAME, 'setPresentationOptions', [options]);
    });
  }

  static async hasRemoteNotificationsEnabled(){
    return new Promise((resolve, reject) => {
      exec(resolve, reject, PLUGIN_NAME, 'hasRemoteNotificationsEnabled', []);
    });
  }

  static async allowedUI(){
    return new Promise((resolve, reject) => {
      exec(resolve, reject, PLUGIN_NAME, 'allowedUI', []);
    });
  }

  static async enableRemoteNotifications(){
    return new Promise((resolve, reject) => {
      exec(resolve, reject, PLUGIN_NAME, 'enableRemoteNotifications', []);
    });
  }

  static async disableRemoteNotifications(){
    return new Promise((resolve, reject) => {
      exec(resolve, reject, PLUGIN_NAME, 'disableRemoteNotifications', []);
    });
  }

  // region Events

  static onNotificationReceived(callback){
    return new EventSubscription('notification_received', callback);
  }

  static onSystemNotificationReceived(callback){
    return new EventSubscription('system_notification_received', callback);
  }

  static onUnknownNotificationReceived(callback) {
    return new EventSubscription('unknown_notification_received', callback);
  }

  static onNotificationOpened(callback){
    return new EventSubscription('notification_opened', callback);
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  static onUnknownNotificationOpened(callback){
    return new EventSubscription('unknown_notification_opened', callback);
  }

  static onNotificationActionOpened(callback){
    return new EventSubscription('notification_action_opened', callback);
  }

  static onUnknownNotificationActionOpened(callback){
    return new EventSubscription('unknown_notification_action_opened', callback);
  }

  static onNotificationSettingsChanged(callback) {
    return new EventSubscription('notification_settings_changed', callback);
  }

  static onShouldOpenNotificationSettings(callback) {
    return new EventSubscription('should_open_notification_settings', callback);
  }

  static onFailedToRegisterForRemoteNotifications(callback) {
    return new EventSubscription('failed_to_register_for_remote_notifications', callback);
  }
}