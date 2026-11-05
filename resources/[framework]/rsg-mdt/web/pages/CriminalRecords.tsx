import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { fetchNui, useNuiEvent } from '../hooks/useNui';
import type { IssuedCharge } from '../types';
import { ChargeDetailModal } from '../components/ChargeDetailModal';



function SearchBox({ value, onChange, placeholder }: { value: string; onChange: (v: string) => void; placeholder: string }) {
  return (
    <div className="relative">
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2.5 pl-10 text-white placeholder-zinc-500 focus:outline-none focus:border-amber-600 transition-colors"
      />
      <svg
        className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>
    </div>
  );
}

function RecordItem({ charge, onClick }: { charge: IssuedCharge; onClick: () => void }) {
  const categoryColors: Record<string, string> = {
    felony: 'bg-red-500/20 text-red-400 border-red-500/30',
    misdemeanor: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
    infraction: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  };

  const categoryColor = categoryColors[charge.category || 'misdemeanor'] || categoryColors.misdemeanor;

  return (
    <div
      onClick={onClick}
      className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-4 hover:border-zinc-700 transition-all cursor-pointer group"
    >
      <div className="flex justify-between items-start mb-2">
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <span className={`text-xs px-2 py-0.5 rounded border ${categoryColor}`}>
              {charge.category || 'misdemeanor'}
            </span>
            <span className="text-zinc-500 text-xs">#{charge.id}</span>
          </div>
          <h3 className="text-white font-semibold text-sm group-hover:text-amber-400 transition-colors">
            {charge.charge_name}
          </h3>
        </div>
        <div className="text-right">
          <div className="flex gap-3 text-xs">
            {charge.fine > 0 && (
              <span className="text-zinc-400">
                Fine: <span className="text-green-400">${charge.fine}</span>
              </span>
            )}
            {charge.jailtime > 0 && (
              <span className="text-zinc-400">
                Jail: <span className="text-red-400">{charge.jailtime} mo</span>
              </span>
            )}
          </div>
        </div>
      </div>
      
      <div className="flex items-center gap-2 text-xs text-zinc-400">
        <span className="text-white">{charge.citizen_name}</span>
        <span className="text-zinc-600">•</span>
        <span>{charge.citizenid}</span>
      </div>
      
      {charge.charge_description && (
        <p className="text-zinc-500 text-xs mt-2 line-clamp-1">{charge.charge_description}</p>
      )}
      
      <div className="flex justify-between items-center mt-3 pt-3 border-t border-zinc-800/50 text-xs text-zinc-500">
        <span>Officer: <span className="text-zinc-300">{charge.officer}</span></span>
        <span>{new Date(charge.created_at).toLocaleDateString()}</span>
      </div>
    </div>
  );
}

function RecordList({ charges, loading, onChargeClick }: { charges: IssuedCharge[]; loading: boolean; onChargeClick: (charge: IssuedCharge) => void }) {
  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="text-zinc-500">Loading records...</div>
      </div>
    );
  }

  if (charges.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-zinc-500">
        <svg className="w-12 h-12 mb-3 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <p>No criminal records found</p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {charges.map((charge) => (
        <RecordItem key={charge.id} charge={charge} onClick={() => onChargeClick(charge)} />
      ))}
    </div>
  );
}

interface CriminalRecordsProps {
  viewingChargeId?: number | null;
  onViewReport?: (reportId: number) => void;
  onChargeViewed?: () => void;
}

export function CriminalRecords({ viewingChargeId, onViewReport, onChargeViewed }: CriminalRecordsProps) {
  const [charges, setCharges] = useState<IssuedCharge[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCharge, setSelectedCharge] = useState<IssuedCharge | null>(null);

  const fetchCharges = useCallback(async (query?: string) => {
    setLoading(true);
    const data = await fetchNui<IssuedCharge[]>('getAllIssuedCharges', { query }, []);
    setCharges(data);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchCharges();
  }, [fetchCharges]);

  useEffect(() => {
    if (viewingChargeId && !selectedCharge) {
      fetchNui<IssuedCharge>('getChargeDetails', { id: viewingChargeId }, undefined).then((details) => {
        if (details) {
          setSelectedCharge(details);
          onChargeViewed?.();
        }
      });
    }
  }, [viewingChargeId, selectedCharge, onChargeViewed]);

  const filteredCharges = useMemo(() => {
    if (!searchQuery.trim()) return charges;
    const q = searchQuery.toLowerCase();
    return charges.filter(c => 
      c.citizen_name.toLowerCase().includes(q) ||
      c.citizenid.toLowerCase().includes(q) ||
      c.charge_name.toLowerCase().includes(q) ||
      c.officer.toLowerCase().includes(q) ||
      String(c.id).includes(q)
    );
  }, [charges, searchQuery]);

  useNuiEvent('chargesUpdated', () => {
    fetchCharges(searchQuery || undefined);
  });

  const handleChargeClick = async (charge: IssuedCharge) => {
    const details = await fetchNui<IssuedCharge>('getChargeDetails', { id: charge.id }, charge);
    setSelectedCharge(details);
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-white text-2xl font-bold" style={{ fontFamily: 'var(--font-display)' }}>
            Criminal Records
          </h2>
          <p className="text-zinc-500 text-sm mt-1">
            {filteredCharges.length} {filteredCharges.length === 1 ? 'record' : 'records'}
            {searchQuery && ` matching "${searchQuery}"`}
          </p>
        </div>
        <button
          onClick={() => fetchCharges()}
          className="bg-zinc-800 hover:bg-zinc-700 px-4 py-2 rounded-lg text-zinc-300 text-sm transition-colors flex items-center gap-2"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh
        </button>
      </div>

      <SearchBox
        value={searchQuery}
        onChange={setSearchQuery}
        placeholder="Search by name, citizen ID, charge, or officer..."
      />

      <RecordList
        charges={filteredCharges}
        loading={loading}
        onChargeClick={handleChargeClick}
      />

      {selectedCharge && (
        <ChargeDetailModal
          charge={selectedCharge}
          onClose={() => setSelectedCharge(null)}
          onViewReport={onViewReport}
        />
      )}
    </div>
  );
}
