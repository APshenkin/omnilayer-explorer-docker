from flask import Flask, jsonify, abort, json, make_response, Response, request, g
from cacher import *
import time
import config
from functools import update_wrapper
from debug import *

#init ratelimit redis key store on db 1
redis = lInit(1)

#@app.after_request
#def inject_x_rate_headers(response):
#    limit = get_view_rate_limit()
#    if limit and limit.send_x_headers:
#        h = response.headers
#        h.add('X-RateLimit-Remaining', str(limit.remaining))
#        h.add('X-RateLimit-Limit', str(limit.limit))
#        h.add('X-RateLimit-Reset', str(limit.reset))
#    return response


class RateLimit(object):
    expiration_window = 10

    def __init__(self, key_prefix, limit, per, send_x_headers):
        self.reset = (int(time.time()) // per) * per + per
        self.key = key_prefix + str(self.reset)
        self.key_prefix = key_prefix
        self.limit = limit
        self.per = per
        self.send_x_headers = send_x_headers
        p = redis.pipeline()
        p.incr(self.key)
        p.expireat(self.key, self.reset + self.expiration_window)
        self.current = min(p.execute()[0], limit)

    remaining = property(lambda x: x.limit - x.current)
    over_limit = property(lambda x: x.current >= x.limit)

def get_view_rate_limit():
    return getattr(g, '_view_rate_limit', None)

def on_over_limit(limit):
    akey='triggered/'+limit.key_prefix+time.strftime("%Y-%m-%d", time.gmtime())
    redis.incr(akey)
    print_debug(('Rate Limit Reached: ',str(limit.key)),3)
    return jsonify({'error':True, 'msg':'Rate Limit Reached. Please limit consecutive requests to no more than '+str(limit.limit-10)+' every '+str(limit.per)+'s.'}), 400

def ratelimit(limit, per=300, send_x_headers=True,
              over_limit=on_over_limit,
              scope_func=lambda: request.headers.getlist("X-Forwarded-For")[0] if request.headers.getlist("X-Forwarded-For") else request.remote_addr,
              key_func=lambda: request.endpoint):
    def decorator(f):
        def rate_limited(*args, **kwargs):
            if config.DISABLE_RATE_LIMITS == 'true': return f(*args, **kwargs)
            #endpoint name/ipaddress
            key = 'rate-limit/%s/%s/' % (key_func(), scope_func())
            #just use ipaddress for
            #key = 'rate-limit/%s/' % (scope_func())
            rlimit = RateLimit(key, limit, per, send_x_headers)
            g._view_rate_limit = rlimit
            if over_limit is not None and rlimit.over_limit:
                return over_limit(rlimit)
            return f(*args, **kwargs)
        return update_wrapper(rate_limited, f)
    return decorator
