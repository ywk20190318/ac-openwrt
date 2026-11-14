'use strict';
'require baseclass';
'require form';
'require uci';

function syncMasquerading(before) {
    for (const zone of uci.sections('firewall', 'zone')) {
        const sid = zone['.name'];

        // Preserve an explicit IPv4 masquerading-off choice in this save.
        if (before[sid]?.masq === '1' && uci.get('firewall', sid, 'masq') !== '1')
            uci.set('firewall', sid, 'fullcone', '0');
        else if (before[sid]?.fullcone !== '1' && uci.get('firewall', sid, 'fullcone') === '1')
            uci.set('firewall', sid, 'masq', '1');

        // IPv6 Fullcone and IPv6 masquerading are independent of IPv4.
        if (before[sid]?.masq6 === '1' && uci.get('firewall', sid, 'masq6') !== '1')
            uci.set('firewall', sid, 'fullcone6', '0');
        else if (before[sid]?.fullcone6 !== '1' && uci.get('firewall', sid, 'fullcone6') === '1')
            uci.set('firewall', sid, 'masq6', '1');
    }
}

return baseclass.extend({
    attach(map) {
        const save = map.save.bind(map);
        map.save = function(cb, silent) {
            const before = Object.fromEntries(uci.sections('firewall', 'zone').map(zone => {
                const sid = zone['.name'];
                return [ sid, {
                    masq: uci.get('firewall', sid, 'masq'),
                    masq6: uci.get('firewall', sid, 'masq6'),
                    fullcone: uci.get('firewall', sid, 'fullcone'),
                    fullcone6: uci.get('firewall', sid, 'fullcone6')
                } ];
            }));
            return save(() => {
                for (const defaults of uci.sections('firewall', 'defaults')) {
                    uci.set('firewall', defaults['.name'], 'flow_offloading', '0');
                    uci.set('firewall', defaults['.name'], 'flow_offloading_hw', '0');
                }
                syncMasquerading(before);
                return cb ? cb() : undefined;
            }, silent);
        };
    },

    addGlobal(section) {
        let o = section.option(form.Flag, 'fullcone', _('Fullcone NAT'));
        o.default = '1';
        o.rmempty = false;

        o = section.option(form.Flag, 'fullcone6', _('Fullcone NAT (IPv6)'),
            _('Enable IPv6 Fullcone NAT independently of IPv4.'));
        o.default = '0';
        o.rmempty = false;
        return o;
    },

    addZone(section) {
        let o = section.taboption('general', form.Flag, 'fullcone', _('Fullcone NAT'),
            _('Uses all supported protocols. Enabling IPv4 Fullcone NAT automatically enables IPv4 masquerading. Disabling IPv4 masquerading also disables IPv4 Fullcone NAT for this zone. Disabling IPv4 Fullcone NAT leaves IPv4 masquerading unchanged. Usually enable this only on the WAN zone.'));
        o.editable = true;
        o.default = '0';
        o.rmempty = false;

        o = section.taboption('general', form.Flag, 'fullcone6', _('Fullcone NAT (IPv6)'),
            _('Uses all supported protocols. Enabling IPv6 Fullcone NAT automatically enables IPv6 masquerading. Disabling IPv6 masquerading also disables IPv6 Fullcone NAT for this zone. Disabling IPv6 Fullcone NAT leaves IPv6 masquerading unchanged. Usually enable this only on the WAN zone.'));
        o.editable = true;
        o.default = '0';
        o.rmempty = false;

        section.addModalOptions = modal => this.attach(modal.map);
        return o;
    }
});
