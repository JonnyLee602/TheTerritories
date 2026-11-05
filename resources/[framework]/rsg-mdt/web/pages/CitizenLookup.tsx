import { useState, useEffect, useMemo } from 'react';
import { fetchNui } from '../hooks/useNui';
import type { Citizen } from '../types';
import { ProfileModal } from '../components/ProfileModal';

interface CitizenLookupProps {
  onIssueWarrant?: (citizenid: string, name: string) => void;
  onViewReport?: (reportId: number) => void;
}

export function CitizenLookup({ onIssueWarrant, onViewReport }: CitizenLookupProps) {
  const [query, setQuery] = useState('');
  const [allCitizens, setAllCitizens] = useState<Citizen[]>([]);
  const [selected, setSelected] = useState<Citizen | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchCitizens = async () => {
      setLoading(true);
      const data = await fetchNui<Citizen[]>('getAllCitizens', {}, [
        { citizenid: 'CIT001', charinfo: { firstname: 'John', lastname: 'Marston', gender: 0, birthdate: '1873-05-21' }, job: { name: 'outlaw', label: 'Outlaw', grade: { name: 'Member' } }, isWanted: true },
        { citizenid: 'CIT002', charinfo: { firstname: 'Arthur', lastname: 'Morgan', gender: 0, birthdate: '1863-06-14' }, job: { name: 'cowboy', label: 'Cowboy', grade: { name: 'Member' } }, isWanted: false },
        { citizenid: 'CIT003', charinfo: { firstname: 'Sadie', lastname: 'Adler', gender: 1, birthdate: '1869-08-12' }, job: { name: 'bounty', label: 'Bounty Hunter', grade: { name: 'Senior' } }, isWanted: false },
        { citizenid: 'CIT004', charinfo: { firstname: 'Dutch', lastname: 'van der Linde', gender: 0, birthdate: '1855-02-08' }, job: { name: 'leader', label: 'Gang Leader', grade: { name: 'Boss' } }, isWanted: true },
        { citizenid: 'CIT005', charinfo: { firstname: 'Charles', lastname: 'Smith', gender: 0, birthdate: '1869-03-15' }, job: { name: 'hunter', label: 'Hunter', grade: { name: 'Member' } }, isWanted: false },
      ]);
      setAllCitizens(data);
      setLoading(false);
    };
    fetchCitizens();
  }, []);

  const filteredCitizens = useMemo(() => {
    if (!query.trim()) return allCitizens;
    const searchTerms = query.toLowerCase().split(/\s+/).filter(Boolean);
    return allCitizens.filter((citizen) => {
      const citizenid = citizen.citizenid.toLowerCase();
      const firstname = citizen.charinfo?.firstname?.toLowerCase() || '';
      const lastname = citizen.charinfo?.lastname?.toLowerCase() || '';
      const fullname = `${firstname} ${lastname}`;
      return searchTerms.every(
        (term) =>
          citizenid.includes(term) ||
          firstname.includes(term) ||
          lastname.includes(term) ||
          fullname.includes(term)
      );
    });
  }, [allCitizens, query]);

  const handleViewProfile = async (citizen: Citizen) => {
    const data = await fetchNui<Citizen>('getCitizen', { citizenid: citizen.citizenid }, {
      citizenid: citizen.citizenid,
      charinfo: citizen.charinfo,
      job: citizen.job,
      money: { cash: 150, bank: 2500, bloodmoney: 50 },
      metadata: {},
      profilePicture: null,
      isWanted: citizen.isWanted,
      records: [],
    });
    setSelected(data);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-white text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
        Citizen Lookup
      </h2>

      <div className="flex gap-3">
        <input
          type="text"
          placeholder="Filter by name or citizen ID..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="flex-1 bg-zinc-900 border border-zinc-800 rounded-lg px-4 py-3 text-white placeholder-zinc-600 focus:outline-none focus:border-amber-600"
        />
      </div>

      <div className="text-zinc-500 text-sm">
        Showing {filteredCitizens.length} of {allCitizens.length} citizens
      </div>

      {loading ? (
        <div className="text-zinc-400 text-center py-8">Loading citizens...</div>
      ) : (
        <div className="bg-zinc-900/50 border border-zinc-800 rounded-lg overflow-hidden">
          <table className="w-full">
            <thead className="bg-zinc-800/50">
              <tr>
                <th className="px-4 py-3 text-left text-zinc-400 text-sm font-medium uppercase tracking-wider">Citizen ID</th>
                <th className="px-4 py-3 text-left text-zinc-400 text-sm font-medium uppercase tracking-wider">Name</th>
                <th className="px-4 py-3 text-left text-zinc-400 text-sm font-medium uppercase tracking-wider">Gender</th>
                <th className="px-4 py-3 text-left text-zinc-400 text-sm font-medium uppercase tracking-wider">Status</th>
                <th className="px-4 py-3 text-left text-zinc-400 text-sm font-medium uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800">
              {filteredCitizens.map((citizen) => (
                <tr key={citizen.citizenid} className="hover:bg-zinc-800/30 transition-colors">
                  <td className="px-4 py-3">
                    <span className="text-amber-400 font-mono text-sm">{citizen.citizenid}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-white">{citizen.charinfo?.firstname} {citizen.charinfo?.lastname}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-zinc-300">{citizen.charinfo?.gender === 0 ? 'Male' : 'Female'}</span>
                  </td>
                  <td className="px-4 py-3">
                    {citizen.isWanted ? (
                      <span className="inline-flex items-center gap-1.5 bg-red-600/20 text-red-400 border border-red-600/30 px-2.5 py-1 rounded text-xs font-semibold uppercase">
                        <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                        </svg>
                        Wanted
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1.5 bg-green-600/20 text-green-400 border border-green-600/30 px-2.5 py-1 rounded text-xs font-semibold uppercase">
                        <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                        </svg>
                        Clear
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <button
                      onClick={() => handleViewProfile(citizen)}
                      className="text-amber-400 hover:text-amber-300 text-sm font-medium transition-colors"
                    >
                      View Profile
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {selected && (
        <ProfileModal
          citizen={selected}
          onClose={() => setSelected(null)}
          onIssueWarrant={onIssueWarrant}
          onChargesIssued={async () => {
            const data = await fetchNui<Citizen>('getCitizen', { citizenid: selected.citizenid }, selected);
            setSelected(data);
          }}
          onViewReport={onViewReport}
          targetPlayerId={selected.playerId}
        />
      )}
    </div>
  );
}
